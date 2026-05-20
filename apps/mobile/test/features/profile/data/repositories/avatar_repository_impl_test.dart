// Unit tests for AvatarRepositoryImpl.
//
// Tests:
//   - happy path: calls updateProfile with the cache-busted URL
//   - Storage succeeds, Firestore updateProfile throws DataException → exception propagates
//   - Retry-once: Firestore fails first call, succeeds second call → no exception thrown

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/profile/data/datasources/avatar_datasource.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/avatar_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockAvatarDatasource extends Mock implements AvatarDatasource {}

class _MockProfileDatasource extends Mock implements ProfileDatasource {}

void main() {
  late _MockAvatarDatasource mockAvatarDs;
  late _MockProfileDatasource mockProfileDs;
  late AvatarRepositoryImpl repo;

  const uid = 'test-uid';
  const cacheBustedUrl =
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/avatar.jpg?alt=media&token=abc&v=1716123456789';

  setUp(() {
    mockAvatarDs = _MockAvatarDatasource();
    mockProfileDs = _MockProfileDatasource();
    repo = AvatarRepositoryImpl(mockAvatarDs, mockProfileDs);

    // Default: streams return empty/null.
    when(
      () => mockAvatarDs.watchLocalPreviewBytes(any()),
    ).thenAnswer((_) => Stream.value(null));
    when(
      () => mockAvatarDs.watchUploadProgress(any()),
    ).thenAnswer((_) => Stream.value(null));
  });

  // ── happy path ────────────────────────────────────────────────────────────

  test('happy path — calls updateProfile with the cache-busted URL', () async {
    when(
      () => mockAvatarDs.pickAndUpload(uid),
    ).thenAnswer((_) async => (url: cacheBustedUrl, compressedSizeBytes: 1024));
    when(
      () => mockProfileDs.updateProfile(
        uid,
        any(
          that: predicate<Map<String, dynamic>>(
            (m) => m['photoUrl'] == cacheBustedUrl,
          ),
        ),
      ),
    ).thenAnswer((_) async {});

    await repo.pickAndUpload(uid);

    verify(
      () => mockProfileDs.updateProfile(
        uid,
        any(
          that: predicate<Map<String, dynamic>>(
            (m) => m['photoUrl'] == cacheBustedUrl,
          ),
        ),
      ),
    ).called(1);
  });

  // ── Storage succeeds, Firestore throws (both attempts) ───────────────────

  test(
    'Storage succeeds, Firestore updateProfile always throws DataException — exception propagates',
    () async {
      when(() => mockAvatarDs.pickAndUpload(uid)).thenAnswer(
        (_) async => (url: cacheBustedUrl, compressedSizeBytes: 512),
      );
      // Both calls (initial + retry) throw DataException.
      when(
        () => mockProfileDs.updateProfile(uid, any()),
      ).thenThrow(const DataException('Firestore write failed'));

      await expectLater(repo.pickAndUpload(uid), throwsA(isA<DataException>()));

      // updateProfile must have been called twice (initial + retry).
      verify(() => mockProfileDs.updateProfile(uid, any())).called(2);
    },
  );

  // ── Retry-once: first call fails, second succeeds ─────────────────────────

  test(
    'Firestore fails first call, succeeds second call — no exception thrown',
    () async {
      when(() => mockAvatarDs.pickAndUpload(uid)).thenAnswer(
        (_) async => (url: cacheBustedUrl, compressedSizeBytes: 512),
      );

      var callCount = 0;
      when(() => mockProfileDs.updateProfile(uid, any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw const DataException('Transient Firestore error');
        }
        // Second call succeeds.
      });

      // Must not throw.
      await expectLater(repo.pickAndUpload(uid), completes);

      expect(
        callCount,
        2,
        reason: 'updateProfile must be called twice (initial + one retry)',
      );
    },
  );

  // ── user cancels picker ───────────────────────────────────────────────────

  test('user cancels picker — returns without calling updateProfile', () async {
    when(() => mockAvatarDs.pickAndUpload(uid)).thenAnswer((_) async => null);

    await repo.pickAndUpload(uid);

    verifyNever(() => mockProfileDs.updateProfile(any(), any()));
  });
}
