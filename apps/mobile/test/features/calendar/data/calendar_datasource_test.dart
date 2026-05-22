// Unit tests for CalendarDatasource.
//
// Verifies that watchSessionsInRange builds the correct Firestore query:
//   - collection(sessionsCollection)
//   - where('memberUids', arrayContains: uid)
//   - where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
//   - where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
//   - orderBy('scheduledAt')
//
// Does NOT hit real Firestore — uses mocktail mocks.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/features/calendar/data/datasources/calendar_datasource.dart';
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

void main() {
  late _MockFirestore mockFirestore;
  late _MockCollectionReference mockCollection;
  late _MockQuery mockQueryAfterArrayContains;
  late _MockQuery mockQueryAfterGte;
  late _MockQuery mockQueryAfterLte;
  late _MockQuery mockQueryAfterOrderBy;
  late _MockQuerySnapshot mockSnapshot;
  late CalendarDatasource datasource;

  const uid = 'test-uid';
  final start = DateTime(2026, 4);
  final end = DateTime(2026, 6, 30, 23, 59, 59);

  setUpAll(() {
    registerFallbackValue(Timestamp.fromDate(DateTime(2000)));
  });

  setUp(() {
    mockFirestore = _MockFirestore();
    mockCollection = _MockCollectionReference();
    mockQueryAfterArrayContains = _MockQuery();
    mockQueryAfterGte = _MockQuery();
    mockQueryAfterLte = _MockQuery();
    mockQueryAfterOrderBy = _MockQuery();
    mockSnapshot = _MockQuerySnapshot();

    datasource = CalendarDatasource(mockFirestore);

    when(
      () => mockFirestore.collection(FirestorePaths.sessionsCollection),
    ).thenReturn(mockCollection);

    when(
      () => mockCollection.where(
        'memberUids',
        arrayContains: any(named: 'arrayContains'),
      ),
    ).thenReturn(mockQueryAfterArrayContains);

    when(
      () => mockQueryAfterArrayContains.where(
        'scheduledAt',
        isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo'),
      ),
    ).thenReturn(mockQueryAfterGte);

    when(
      () => mockQueryAfterGte.where(
        'scheduledAt',
        isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo'),
      ),
    ).thenReturn(mockQueryAfterLte);

    when(
      () => mockQueryAfterLte.orderBy('scheduledAt'),
    ).thenReturn(mockQueryAfterOrderBy);

    when(() => mockSnapshot.docs).thenReturn([]);
    when(
      () => mockQueryAfterOrderBy.snapshots(),
    ).thenAnswer((_) => Stream.value(mockSnapshot));
  });

  group('CalendarDatasource.watchSessionsInRange', () {
    test('queries the sessions collection', () async {
      datasource.watchSessionsInRange(uid, start, end).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockFirestore.collection(FirestorePaths.sessionsCollection),
      ).called(1);
    });

    test('adds memberUids arrayContains filter with correct uid', () async {
      datasource.watchSessionsInRange(uid, start, end).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockCollection.where('memberUids', arrayContains: uid),
      ).called(1);
    });

    test('adds scheduledAt isGreaterThanOrEqualTo filter', () async {
      datasource.watchSessionsInRange(uid, start, end).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockQueryAfterArrayContains.where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        ),
      ).called(1);
    });

    test('adds scheduledAt isLessThanOrEqualTo filter', () async {
      datasource.watchSessionsInRange(uid, start, end).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockQueryAfterGte.where(
          'scheduledAt',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        ),
      ).called(1);
    });

    test('applies orderBy scheduledAt', () async {
      datasource.watchSessionsInRange(uid, start, end).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockQueryAfterLte.orderBy('scheduledAt')).called(1);
    });

    test('returns empty list when snapshot has no docs', () async {
      when(() => mockSnapshot.docs).thenReturn([]);

      final result =
          await datasource.watchSessionsInRange(uid, start, end).first;
      expect(result, isEmpty);
    });
  });
}
