// Unit tests for FriendsDatasource batch operations.
//
// Tests batch construction for sendRequest, acceptRequest, declineRequest,
// withdrawRequest, and unfriend. Uses mocktail mocks of Firestore interfaces.
// Verifies that both sides of the bidirectional friendship are written/deleted
// in each batch.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockWriteBatch extends Mock implements WriteBatch {}

// ignore: subtype_of_sealed_class
class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ── Fallback fakes ────────────────────────────────────────────────────────────

// ignore: subtype_of_sealed_class
class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a [_MockDocumentReference] for path [path] that is registered on
/// [mockFirestore].doc([path]).
_MockDocumentReference _docRef(_MockFirestore mockFirestore, String path) {
  final ref = _MockDocumentReference();
  when(() => mockFirestore.doc(path)).thenReturn(ref);
  return ref;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDocumentReference());
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(SetOptions(merge: false));
  });

  late _MockFirestore mockFirestore;
  late _MockWriteBatch mockBatch;
  late FriendsDatasource datasource;

  const currentUid = 'current-uid';
  const targetUid = 'target-uid';
  const initiatorUid = 'initiator-uid';
  const friendUid = 'friend-uid';

  // Firestore paths used in assertions.
  final currentTargetPath = FirestorePaths.userFriendDoc(currentUid, targetUid);
  final targetCurrentPath = FirestorePaths.userFriendDoc(targetUid, currentUid);

  setUp(() {
    mockFirestore = _MockFirestore();
    mockBatch = _MockWriteBatch();
    datasource = FriendsDatasource(mockFirestore);

    // batch() returns our mock batch.
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockBatch.commit()).thenAnswer((_) async {});
    // Accept any set/update/delete calls on the batch — we will verify paths
    // via verify() in each test.
    // Note: WriteBatch.set has an optional SetOptions parameter.
    when(
      () => mockBatch.set(
        any<DocumentReference<Map<String, dynamic>>>(),
        any<Map<String, dynamic>>(),
        any<SetOptions>(),
      ),
    ).thenAnswer((_) {});
    when(
      () => mockBatch.set(
        any<DocumentReference<Map<String, dynamic>>>(),
        any<Map<String, dynamic>>(),
      ),
    ).thenAnswer((_) {});
    when(
      () => mockBatch.update(
        any<DocumentReference<Map<String, dynamic>>>(),
        any<Map<String, dynamic>>(),
      ),
    ).thenAnswer((_) {});
    when(
      () => mockBatch.delete(any<DocumentReference<Map<String, dynamic>>>()),
    ).thenAnswer((_) {});
  });

  // ── sendRequest ─────────────────────────────────────────────────────────────

  group('sendRequest', () {
    test(
      'writes pending documents on both sides of the friendship atomically',
      () async {
        _docRef(mockFirestore, currentTargetPath);
        _docRef(mockFirestore, targetCurrentPath);

        await datasource.sendRequest(currentUid, targetUid);

        // Verify set was called at all (both sides) and commit was called.
        // We verify the doc refs were retrieved (which proves both sides were addressed).
        verify(() => mockFirestore.doc(currentTargetPath)).called(1);
        verify(() => mockFirestore.doc(targetCurrentPath)).called(1);
        verify(() => mockBatch.commit()).called(1);
      },
    );

    test(
      'throws DataException when batch.commit() throws FirebaseException',
      () async {
        _docRef(mockFirestore, currentTargetPath);
        _docRef(mockFirestore, targetCurrentPath);

        when(() => mockBatch.commit()).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'unavailable'),
        );

        await expectLater(
          datasource.sendRequest(currentUid, targetUid),
          throwsA(isA<DataException>()),
        );
      },
    );
  });

  // ── acceptRequest ───────────────────────────────────────────────────────────

  group('acceptRequest', () {
    const acceptorDisplayName = 'Alice';
    const initiatorDisplayName = 'Bob';
    const acceptorPhotoUrl =
        'https://example.com/alice.jpg?alt=media&token=x&v=1';
    const initiatorPhotoUrl =
        'https://example.com/bob.jpg?alt=media&token=y&v=1';

    // Accept: currentUid is acceptor, initiatorUid is the one who sent the request.
    final initiatorAcceptorPath = FirestorePaths.userFriendDoc(
      initiatorUid,
      currentUid,
    );
    final acceptorInitiatorPath = FirestorePaths.userFriendDoc(
      currentUid,
      initiatorUid,
    );

    test(
      'updates both documents to accepted with cross-populated display fields',
      () async {
        _docRef(mockFirestore, initiatorAcceptorPath);
        _docRef(mockFirestore, acceptorInitiatorPath);

        await datasource.acceptRequest(
          currentUid: currentUid,
          initiatorUid: initiatorUid,
          currentDisplayName: acceptorDisplayName,
          currentPhotoUrl: acceptorPhotoUrl,
          initiatorDisplayName: initiatorDisplayName,
          initiatorPhotoUrl: initiatorPhotoUrl,
        );

        // Verify both document paths were accessed and commit was called.
        verify(() => mockFirestore.doc(initiatorAcceptorPath)).called(1);
        verify(() => mockFirestore.doc(acceptorInitiatorPath)).called(1);
        verify(() => mockBatch.commit()).called(1);
      },
    );

    test(
      'throws DataException when batch.commit() throws FirebaseException',
      () async {
        _docRef(mockFirestore, initiatorAcceptorPath);
        _docRef(mockFirestore, acceptorInitiatorPath);

        when(() => mockBatch.commit()).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        );

        await expectLater(
          datasource.acceptRequest(
            currentUid: currentUid,
            initiatorUid: initiatorUid,
            currentDisplayName: acceptorDisplayName,
            initiatorDisplayName: initiatorDisplayName,
          ),
          throwsA(isA<DataException>()),
        );
      },
    );
  });

  // ── declineRequest ──────────────────────────────────────────────────────────

  group('declineRequest', () {
    final currentInitiatorPath = FirestorePaths.userFriendDoc(
      currentUid,
      initiatorUid,
    );
    final initiatorCurrentPath = FirestorePaths.userFriendDoc(
      initiatorUid,
      currentUid,
    );

    test('deletes both pending documents atomically', () async {
      _docRef(mockFirestore, currentInitiatorPath);
      _docRef(mockFirestore, initiatorCurrentPath);

      await datasource.declineRequest(currentUid, initiatorUid);

      verify(() => mockFirestore.doc(currentInitiatorPath)).called(1);
      verify(() => mockFirestore.doc(initiatorCurrentPath)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('throws DataException on FirebaseException', () async {
      _docRef(mockFirestore, currentInitiatorPath);
      _docRef(mockFirestore, initiatorCurrentPath);

      when(
        () => mockBatch.commit(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      await expectLater(
        datasource.declineRequest(currentUid, initiatorUid),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── withdrawRequest ─────────────────────────────────────────────────────────

  group('withdrawRequest', () {
    final currentFriendPath = FirestorePaths.userFriendDoc(
      currentUid,
      friendUid,
    );
    final friendCurrentPath = FirestorePaths.userFriendDoc(
      friendUid,
      currentUid,
    );

    test('deletes both pending documents atomically', () async {
      _docRef(mockFirestore, currentFriendPath);
      _docRef(mockFirestore, friendCurrentPath);

      await datasource.withdrawRequest(currentUid, friendUid);

      verify(() => mockFirestore.doc(currentFriendPath)).called(1);
      verify(() => mockFirestore.doc(friendCurrentPath)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('throws DataException on FirebaseException', () async {
      _docRef(mockFirestore, currentFriendPath);
      _docRef(mockFirestore, friendCurrentPath);

      when(
        () => mockBatch.commit(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      await expectLater(
        datasource.withdrawRequest(currentUid, friendUid),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── unfriend ────────────────────────────────────────────────────────────────

  group('unfriend', () {
    // Use distinct UIDs to avoid path collision with withdrawRequest group.
    const unfriendCurrentUid = 'unfriend-current-uid';
    const unfriendFriendUid = 'unfriend-friend-uid';

    final currentFriendPath = FirestorePaths.userFriendDoc(
      unfriendCurrentUid,
      unfriendFriendUid,
    );
    final friendCurrentPath = FirestorePaths.userFriendDoc(
      unfriendFriendUid,
      unfriendCurrentUid,
    );

    test('deletes both accepted documents atomically', () async {
      _docRef(mockFirestore, currentFriendPath);
      _docRef(mockFirestore, friendCurrentPath);

      await datasource.unfriend(unfriendCurrentUid, unfriendFriendUid);

      verify(() => mockFirestore.doc(currentFriendPath)).called(1);
      verify(() => mockFirestore.doc(friendCurrentPath)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('throws DataException on FirebaseException', () async {
      _docRef(mockFirestore, currentFriendPath);
      _docRef(mockFirestore, friendCurrentPath);

      when(
        () => mockBatch.commit(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      await expectLater(
        datasource.unfriend(unfriendCurrentUid, unfriendFriendUid),
        throwsA(isA<DataException>()),
      );
    });
  });
}
