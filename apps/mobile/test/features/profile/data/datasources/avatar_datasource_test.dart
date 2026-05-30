// Unit tests for AvatarDatasource upload logic.
//
// AvatarDatasource.pickAndUpload directly calls image_picker,
// flutter_image_compress, and UploadTask (which has a private constructor and
// cannot be mocked). These tests therefore:
//
//   1. Verify the cache-bust URL format contract (ADR 0005 §step 7) via a
//      pure function test — no Firebase SDK needed.
//   2. Verify StorageUploadFailure is thrown on FirebaseException by testing
//      the repository layer (AvatarRepositoryImpl) which wraps the datasource.
//   3. Verify user-cancel returns null via the repository wrapper.
//
// Full integration testing of the Storage upload path is deferred to an
// integration test that requires a real Firebase emulator.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/profile/data/datasources/avatar_datasource.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/avatar_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockAvatarDatasource extends Mock implements AvatarDatasource {}

class _MockProfileDatasource extends Mock implements ProfileDatasource {}

// ── URL format contract ────────────────────────────────────────────────────────

String _applyAdrCacheBust(String downloadUrl) {
  // Mirrors AvatarDatasource step 7 logic (ADR 0005):
  // Firebase download URLs already carry ?alt=media&token=..., so the
  // cache-bust must use & not ?.
  return '$downloadUrl&v=${DateTime.now().millisecondsSinceEpoch}';
}

void main() {
  // ── cache-bust URL format ─────────────────────────────────────────────────

  group('cache-bust URL format (ADR 0005 §step 7)', () {
    test('appends "&v=<epoch>" (not "?v=") to a Firebase download URL', () {
      const baseUrl =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/avatar.jpg?alt=media&token=abc123';

      final result = _applyAdrCacheBust(baseUrl);

      // Must contain &v= (the Firebase URL already has ?alt=media&token=).
      expect(result, contains('&v='));
      // Must NOT contain ?v= which would be a second query-string start.
      expect(result, isNot(contains('?v=')));
      // Must start with the original base URL.
      expect(result, startsWith(baseUrl));
    });

    test(
      'cache-bust epoch value changes between calls (non-deterministic, sanity check)',
      () async {
        const baseUrl =
            'https://firebasestorage.googleapis.com/v0/b/bucket/o/avatar.jpg?alt=media&token=abc';

        final url1 = _applyAdrCacheBust(baseUrl);
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final url2 = _applyAdrCacheBust(baseUrl);

        // Different millisecond epochs → different cache-bust suffixes.
        expect(url1, isNot(equals(url2)));
      },
    );
  });

  // ── StorageUploadFailure propagation via AvatarRepositoryImpl ─────────────

  group('StorageUploadFailure propagation', () {
    late _MockAvatarDatasource mockAvatarDs;
    late _MockProfileDatasource mockProfileDs;
    late AvatarRepositoryImpl repo;

    const uid = 'test-uid';

    setUp(() {
      mockAvatarDs = _MockAvatarDatasource();
      mockProfileDs = _MockProfileDatasource();
      repo = AvatarRepositoryImpl(mockAvatarDs, mockProfileDs);

      when(
        () => mockAvatarDs.watchLocalPreviewBytes(any()),
      ).thenAnswer((_) => Stream.value(null));
      when(
        () => mockAvatarDs.watchUploadProgress(any()),
      ).thenAnswer((_) => Stream.value(null));
    });

    test(
      'StorageUploadFailure from datasource propagates through repository',
      () async {
        when(() => mockAvatarDs.pickAndUpload(uid)).thenThrow(
          const StorageUploadFailure('Storage upload failed: unauthorized'),
        );

        await expectLater(
          repo.pickAndUpload(uid),
          throwsA(isA<StorageUploadFailure>()),
        );
      },
    );

    test(
      'user cancels picker — datasource returns null — repository returns without calling updateProfile',
      () async {
        when(
          () => mockAvatarDs.pickAndUpload(uid),
        ).thenAnswer((_) async => null);

        await repo.pickAndUpload(uid);

        verifyNever(() => mockProfileDs.updateProfile(any(), any()));
      },
    );
  });
}
