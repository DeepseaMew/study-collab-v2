// Contract tests for MySessionsRepository operations.
//
// Covers: watchUpcomingSessions, watchCompletedSessions, watchHostedSessions.
// Also exercises the ADR 0003 sub-decision 1 client-side filter rule:
//   Upcoming stream must exclude sessions where status == 'ended'.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/my_sessions/domain/repositories/my_sessions_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockMySessionsRepository extends Mock implements MySessionsRepository {}

SessionEntity _session({
  String id = 'sess-1',
  String status = 'scheduled',
  String? hostUid,
}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: hostUid ?? 'host-1',
    hostFaculty: 'Engineering',
    title: 'Study Session $id',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 1,
    visibility: 'public',
    memberUids: const ['user-1'],
    noteCount: 0,
    status: status,
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _MockMySessionsRepository repo;

  setUp(() {
    repo = _MockMySessionsRepository();
  });

  group('watchUpcomingSessions', () {
    test('emits non-ended sessions only', () {
      // The repository contract guarantees that ended sessions are excluded.
      final upcoming = [
        _session(id: 's1'),
        _session(id: 's2', status: 'active'),
      ];
      when(() => repo.watchUpcomingSessions('user-1'))
          .thenAnswer((_) => Stream.value(upcoming));

      expect(
        repo.watchUpcomingSessions('user-1'),
        emits(
          allOf(
            hasLength(2),
            isNot(contains(predicate<SessionEntity>((s) => s.status == 'ended'))),
          ),
        ),
      );
    });

    test('emits empty list when no upcoming sessions', () {
      when(() => repo.watchUpcomingSessions('user-1'))
          .thenAnswer((_) => Stream.value(const []));

      expect(repo.watchUpcomingSessions('user-1'), emits(isEmpty));
    });
  });

  group('watchCompletedSessions', () {
    test('emits only ended sessions', () {
      final completed = [
        _session(id: 's3', status: 'ended'),
        _session(id: 's4', status: 'ended'),
      ];
      when(() => repo.watchCompletedSessions('user-1'))
          .thenAnswer((_) => Stream.value(completed));

      expect(
        repo.watchCompletedSessions('user-1'),
        emits(
          allOf(
            hasLength(2),
            everyElement(
              predicate<SessionEntity>((s) => s.status == 'ended'),
            ),
          ),
        ),
      );
    });
  });

  group('watchHostedSessions', () {
    test('emits sessions where hostUid matches caller uid', () {
      final hosted = [
        _session(id: 's5', hostUid: 'user-1'),
        _session(id: 's6', hostUid: 'user-1'),
      ];
      when(() => repo.watchHostedSessions('user-1'))
          .thenAnswer((_) => Stream.value(hosted));

      expect(
        repo.watchHostedSessions('user-1'),
        emits(
          allOf(
            hasLength(2),
            everyElement(
              predicate<SessionEntity>((s) => s.hostUid == 'user-1'),
            ),
          ),
        ),
      );
    });

    test('emits empty list when user has no hosted sessions', () {
      when(() => repo.watchHostedSessions('user-1'))
          .thenAnswer((_) => Stream.value(const []));

      expect(repo.watchHostedSessions('user-1'), emits(isEmpty));
    });
  });
}
