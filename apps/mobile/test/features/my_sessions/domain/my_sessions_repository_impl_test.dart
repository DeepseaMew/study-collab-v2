// Unit tests for MySessionsRepositoryImpl client-side filters.
//
// ADR 0003 sub-decision 1: both Upcoming and Completed reuse
// watchMemberSessionsForUpcoming (Index 1) and apply time-based client-side
// filtering in the repository layer.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/my_sessions/data/repositories/my_sessions_repository_impl.dart';
import 'package:mobile/features/my_sessions/data/datasources/my_sessions_datasource.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockMySessionsDatasource extends Mock implements MySessionsDatasource {}

// Far-future and far-past sentinels — independent of when the test runs.
final _future = DateTime(2099, 6, 15);
final _past = DateTime(2020, 6, 15);

/// Minimal SessionModel factory for testing.
SessionModel _model({
  required String id,
  required String status,
  String hostUid = 'host-1',
  String visibility = 'public',
  DateTime? scheduledEndAt,
}) {
  final baseNow = DateTime(2026, 5, 18, 10);
  return SessionModel(
    sessionId: id,
    hostUid: hostUid,
    hostFaculty: 'Engineering',
    title: 'Session $id',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 1,
    visibility: visibility,
    memberUids: const ['u1'],
    noteCount: 0,
    status: status,
    scheduledAt: baseNow,
    scheduledEndAt: scheduledEndAt,
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: baseNow,
    updatedAt: baseNow,
  );
}

void main() {
  late _MockMySessionsDatasource datasource;
  late MySessionsRepositoryImpl repo;

  setUp(() {
    datasource = _MockMySessionsDatasource();
    repo = MySessionsRepositoryImpl(datasource);
  });

  group('watchUpcomingSessions client-side filter', () {
    test('filters out sessions with status ended', () async {
      final models = [
        _model(id: 's1', status: 'scheduled'),
        _model(id: 's2', status: 'active'),
        _model(id: 's3', status: 'ended'),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchUpcomingSessions('u1').first;

      expect(entities.length, 2);
      expect(entities.every((e) => e.status != 'ended'), isTrue);
    });

    test('returns empty when all sessions have ended', () async {
      final models = [
        _model(id: 's1', status: 'ended'),
        _model(id: 's2', status: 'ended'),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchUpcomingSessions('u1').first;

      expect(entities, isEmpty);
    });

    test(
      'passes through all sessions when none are ended and all in future',
      () async {
        final models = [
          _model(id: 's1', status: 'scheduled'),
          _model(id: 's2', status: 'scheduled'),
        ];
        when(
          () => datasource.watchMemberSessionsForUpcoming('u1'),
        ).thenAnswer((_) => Stream.value(models));

        final entities = await repo.watchUpcomingSessions('u1').first;

        expect(entities.length, 2);
      },
    );

    test('filters out sessions past their scheduled end time', () async {
      final models = [
        _model(id: 's1', status: 'scheduled', scheduledEndAt: _future),
        _model(id: 's2', status: 'scheduled', scheduledEndAt: _past),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchUpcomingSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
    });

    test(
      'keeps session with null scheduledEndAt and non-ended status',
      () async {
        final models = [_model(id: 's1', status: 'scheduled')];
        when(
          () => datasource.watchMemberSessionsForUpcoming('u1'),
        ).thenAnswer((_) => Stream.value(models));

        final entities = await repo.watchUpcomingSessions('u1').first;

        expect(entities.length, 1);
      },
    );

    test('excludes private session hosted by the caller', () async {
      final models = [
        _model(id: 's1', status: 'scheduled'),
        _model(
          id: 's2',
          status: 'scheduled',
          hostUid: 'u1',
          visibility: 'private',
        ),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchUpcomingSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
    });

    test('keeps private session where caller is a member (not host)', () async {
      final models = [
        _model(
          id: 's1',
          status: 'scheduled',
          hostUid: 'other-host',
          visibility: 'private',
        ),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchUpcomingSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
    });
  });

  group('watchCompletedSessions', () {
    test('includes session with status ended', () async {
      final models = [
        _model(id: 's1', status: 'ended', scheduledEndAt: _future),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchCompletedSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
      expect(entities.first.status, 'ended');
    });

    test(
      'includes session past scheduledEndAt even if not explicitly ended',
      () async {
        final models = [
          _model(id: 's1', status: 'scheduled', scheduledEndAt: _past),
        ];
        when(
          () => datasource.watchMemberSessionsForUpcoming('u1'),
        ).thenAnswer((_) => Stream.value(models));

        final entities = await repo.watchCompletedSessions('u1').first;

        expect(entities.length, 1);
        expect(entities.first.sessionId, 's1');
      },
    );

    test(
      'excludes session with future scheduledEndAt and non-ended status',
      () async {
        final models = [
          _model(id: 's1', status: 'scheduled', scheduledEndAt: _future),
        ];
        when(
          () => datasource.watchMemberSessionsForUpcoming('u1'),
        ).thenAnswer((_) => Stream.value(models));

        final entities = await repo.watchCompletedSessions('u1').first;

        expect(entities, isEmpty);
      },
    );

    test(
      'excludes session with null scheduledEndAt and non-ended status',
      () async {
        final models = [_model(id: 's1', status: 'scheduled')];
        when(
          () => datasource.watchMemberSessionsForUpcoming('u1'),
        ).thenAnswer((_) => Stream.value(models));

        final entities = await repo.watchCompletedSessions('u1').first;

        expect(entities, isEmpty);
      },
    );

    test('excludes private session hosted by the caller', () async {
      final models = [
        _model(id: 's1', status: 'ended', scheduledEndAt: _past),
        _model(
          id: 's2',
          status: 'ended',
          scheduledEndAt: _past,
          hostUid: 'u1',
          visibility: 'private',
        ),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchCompletedSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
    });

    test('keeps private session where caller is a member (not host)', () async {
      final models = [
        _model(
          id: 's1',
          status: 'ended',
          scheduledEndAt: _past,
          hostUid: 'other-host',
          visibility: 'private',
        ),
      ];
      when(
        () => datasource.watchMemberSessionsForUpcoming('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchCompletedSessions('u1').first;

      expect(entities.length, 1);
      expect(entities.first.sessionId, 's1');
    });
  });

  group('watchHostedSessions', () {
    test('maps datasource models to entities', () async {
      final models = [
        _model(id: 's1', status: 'scheduled'),
        _model(id: 's2', status: 'ended'),
      ];
      when(
        () => datasource.watchHostedSessions('u1'),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchHostedSessions('u1').first;

      expect(entities.length, 2);
    });
  });
}
