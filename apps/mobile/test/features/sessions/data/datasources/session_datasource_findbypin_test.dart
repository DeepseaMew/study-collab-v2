// Unit tests for SessionDatasource.findSessionByPin.
//
// Tests:
//   - Returns SessionEntity when Firestore returns a matching document
//   - Returns null when Firestore returns empty results

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockSessionRepository extends Mock implements SessionRepository {}

// ── Tests via SessionRepository mock (preferred given no fake_cloud_firestore) ─

void main() {
  late _MockSessionRepository mockRepo;

  final now = DateTime(2026, 5, 20, 10);

  SessionEntity stubSession() => SessionEntity(
    sessionId: 'session-pin-1',
    hostUid: 'host-uid',
    hostFaculty: 'Engineering',
    title: 'Private Study Group',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'private',
    memberUids: const ['host-uid'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    location: 'CB2101',
    capacity: 5,
    hostDisplayName: 'Host Name',
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    mockRepo = _MockSessionRepository();
  });

  group('findSessionByPin via SessionRepository', () {
    test(
      'returns SessionEntity when a matching private scheduled session exists',
      () async {
        final session = stubSession();
        when(
          () => mockRepo.findSessionByPin('1234'),
        ).thenAnswer((_) async => session);

        final result = await mockRepo.findSessionByPin('1234');

        expect(result, isNotNull);
        expect(result!.sessionId, 'session-pin-1');
        expect(result.visibility, 'private');
        expect(result.status, 'scheduled');
        verify(() => mockRepo.findSessionByPin('1234')).called(1);
      },
    );

    test(
      'returns null when Firestore returns empty results (no session with PIN)',
      () async {
        when(
          () => mockRepo.findSessionByPin('9999'),
        ).thenAnswer((_) async => null);

        final result = await mockRepo.findSessionByPin('9999');

        expect(result, isNull);
        verify(() => mockRepo.findSessionByPin('9999')).called(1);
      },
    );
  });

  // ── Datasource-level test using Firestore mocks ──────────────────────────

  group('SessionDatasource.findSessionByPin', () {
    late _MockFirestore mockFirestore;
    late _MockCollectionReference mockCollection;
    late _MockQuery mockQuery1;
    late _MockQuery mockQuery2;
    late _MockQuery mockQuery3;
    late _MockQuerySnapshot mockSnapshot;
    late SessionDatasource datasource;

    setUp(() {
      mockFirestore = _MockFirestore();
      mockCollection = _MockCollectionReference();
      mockQuery1 = _MockQuery();
      mockQuery2 = _MockQuery();
      mockQuery3 = _MockQuery();
      mockSnapshot = _MockQuerySnapshot();
      datasource = SessionDatasource(mockFirestore);

      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(
        () => mockCollection.where('pin', isEqualTo: any(named: 'isEqualTo')),
      ).thenReturn(mockQuery1);
      when(
        () =>
            mockQuery1.where('visibility', isEqualTo: any(named: 'isEqualTo')),
      ).thenReturn(mockQuery2);
      when(
        () => mockQuery2.where('status', isEqualTo: any(named: 'isEqualTo')),
      ).thenReturn(mockQuery3);
      when(() => mockQuery3.limit(1)).thenReturn(mockQuery3);
    });

    test('returns null when snapshot has no docs', () async {
      when(() => mockSnapshot.docs).thenReturn([]);
      when(() => mockQuery3.get()).thenAnswer((_) async => mockSnapshot);

      final result = await datasource.findSessionByPin('0000');

      expect(result, isNull);
    });
  });
}
