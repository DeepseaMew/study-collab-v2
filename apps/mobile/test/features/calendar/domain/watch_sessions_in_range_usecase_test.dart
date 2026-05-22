// Unit tests for WatchSessionsInRangeUseCase.
//
// Verifies that the use case delegates to the repository interface correctly
// without adding extra logic.  Uses a mock implementation — no real Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:mobile/features/calendar/domain/usecases/watch_sessions_in_range_usecase.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockCalendarRepository extends Mock implements CalendarRepository {}

SessionEntity _session({
  required String id,
  required DateTime scheduledAt,
}) {
  return SessionEntity(
    sessionId: id,
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Session $id',
    hashtags: const [],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['uid-1'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: scheduledAt,
    location: 'Room A',
    capacity: 10,
    hostDisplayName: 'Host',
    createdAt: scheduledAt,
    updatedAt: scheduledAt,
  );
}

void main() {
  late _MockCalendarRepository repo;
  late WatchSessionsInRangeUseCase useCase;

  setUp(() {
    repo = _MockCalendarRepository();
    useCase = WatchSessionsInRangeUseCase(repo);
  });

  group('WatchSessionsInRangeUseCase', () {
    test('delegates call() to repository.watchSessionsInRange', () {
      final start = DateTime(2026, 5);
      final end = DateTime(2026, 5, 31);
      const uid = 'uid-1';

      final session = _session(
        id: 'sess-a',
        scheduledAt: DateTime(2026, 5, 15),
      );
      when(
        () => repo.watchSessionsInRange(uid, start, end),
      ).thenAnswer((_) => Stream.value([session]));

      final stream = useCase(uid, start, end);

      expect(stream, emits([session]));
      verify(() => repo.watchSessionsInRange(uid, start, end)).called(1);
    });

    test('returns empty list when repository emits empty', () {
      final start = DateTime(2026, 5);
      final end = DateTime(2026, 5, 31);
      const uid = 'uid-1';

      when(
        () => repo.watchSessionsInRange(uid, start, end),
      ).thenAnswer((_) => Stream.value(const <SessionEntity>[]));

      final stream = useCase(uid, start, end);

      expect(stream, emits(isEmpty));
    });

    test('propagates repository stream error', () {
      final start = DateTime(2026, 5);
      final end = DateTime(2026, 5, 31);
      const uid = 'uid-1';

      when(
        () => repo.watchSessionsInRange(uid, start, end),
      ).thenAnswer((_) => Stream.error(Exception('firestore-error')));

      final stream = useCase(uid, start, end);

      expect(stream, emitsError(isA<Exception>()));
    });

    test('passes correct uid, start, and end to repository', () {
      final start = DateTime(2026, 4);
      final end = DateTime(2026, 6, 30);
      const uid = 'test-uid-xyz';

      when(
        () => repo.watchSessionsInRange(uid, start, end),
      ).thenAnswer((_) => Stream.value(const []));

      useCase(uid, start, end);

      verify(() => repo.watchSessionsInRange(uid, start, end)).called(1);
    });

    test('returns multiple sessions from repository', () async {
      final start = DateTime(2026, 5);
      final end = DateTime(2026, 5, 31);
      const uid = 'uid-1';

      final sessions = [
        _session(id: 'sess-a', scheduledAt: DateTime(2026, 5, 10)),
        _session(id: 'sess-b', scheduledAt: DateTime(2026, 5, 20)),
      ];

      when(
        () => repo.watchSessionsInRange(uid, start, end),
      ).thenAnswer((_) => Stream.value(sessions));

      final result = await useCase(uid, start, end).first;
      expect(result.length, 2);
      expect(result[0].sessionId, 'sess-a');
      expect(result[1].sessionId, 'sess-b');
    });
  });
}
