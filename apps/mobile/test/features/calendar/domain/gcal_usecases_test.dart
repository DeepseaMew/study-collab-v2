// Unit tests for the three Google Calendar use cases:
//   ConnectGCalUseCase  — reads user email from UserRepository then calls
//                         CalendarSyncRepository.connect(email).
//   SyncGCalUseCase     — delegates to CalendarSyncRepository.syncSessions.
//   DisconnectGCalUseCase — delegates to CalendarSyncRepository.disconnect.
//
// No real Firebase, Firestore, or Google Sign-In — all dependencies are
// mocktail mocks.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/calendar/domain/usecases/connect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/disconnect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/sync_gcal_usecase.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockCalendarSyncRepository extends Mock
    implements CalendarSyncRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

UserEntity _user({String email = 'student@mail.kmutt.ac.th'}) {
  return UserEntity(
    uid: 'uid-1',
    displayName: 'Test User',
    fullName: 'Test Full User',
    email: email,
    hasHostedBefore: false,
    studentYear: 2,
    academicLevel: 'undergraduate',
    faculty: 'Engineering',
    profileScore: 0.0,
  );
}

SessionEntity _session({String id = 'sess-1'}) {
  final now = DateTime(2026, 5, 20, 14);
  return SessionEntity(
    sessionId: id,
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Study Session $id',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['uid-1'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'Room A',
    capacity: 10,
    hostDisplayName: 'Host',
    createdAt: now,
    updatedAt: now,
  );
}

SyncResult _syncResult({int synced = 1, int failed = 0}) {
  return SyncResult(
    syncedCount: synced,
    failedCount: failed,
    syncedAt: DateTime(2026, 5, 20, 15),
  );
}

// ── ConnectGCalUseCase ────────────────────────────────────────────────────────

void main() {
  late _MockCalendarSyncRepository mockSyncRepo;
  late _MockUserRepository mockUserRepo;

  setUp(() {
    mockSyncRepo = _MockCalendarSyncRepository();
    mockUserRepo = _MockUserRepository();
  });

  group('ConnectGCalUseCase', () {
    ConnectGCalUseCase makeConnectUseCase({String uid = 'uid-1'}) {
      return ConnectGCalUseCase(
        syncRepository: mockSyncRepo,
        userRepository: mockUserRepo,
        uid: uid,
      );
    }

    test('reads user from UserRepository with correct uid', () async {
      const uid = 'uid-42';
      when(
        () => mockUserRepo.watchUser(uid),
      ).thenAnswer((_) => Stream.value(_user()));
      when(
        () => mockSyncRepo.connect(any()),
      ).thenAnswer((_) async {});

      await makeConnectUseCase(uid: uid)();

      verify(() => mockUserRepo.watchUser(uid)).called(1);
    });

    test('passes email from UserRepository to CalendarSyncRepository.connect',
        () async {
      const email = 'testuser@mail.kmutt.ac.th';
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(_user(email: email)));
      when(
        () => mockSyncRepo.connect(email),
      ).thenAnswer((_) async {});

      await makeConnectUseCase()();

      verify(() => mockSyncRepo.connect(email)).called(1);
    });

    test('passes correct email when user has @kmutt.ac.th domain', () async {
      const email = 'staff@kmutt.ac.th';
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(_user(email: email)));
      when(
        () => mockSyncRepo.connect(email),
      ).thenAnswer((_) async {});

      await makeConnectUseCase()();

      verify(() => mockSyncRepo.connect(email)).called(1);
    });

    test('throws StateError when UserRepository emits null (user not found)',
        () async {
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(null));

      await expectLater(
        () => makeConnectUseCase()(),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => mockSyncRepo.connect(any()));
    });

    test('propagates EmailMismatchError from CalendarSyncRepository', () async {
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(_user()));
      when(
        () => mockSyncRepo.connect(any()),
      ).thenThrow(EmailMismatchError());

      await expectLater(
        () => makeConnectUseCase()(),
        throwsA(isA<EmailMismatchError>()),
      );
    });

    test('propagates CancelledError from CalendarSyncRepository', () async {
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(_user()));
      when(
        () => mockSyncRepo.connect(any()),
      ).thenThrow(CancelledError());

      await expectLater(
        () => makeConnectUseCase()(),
        throwsA(isA<CancelledError>()),
      );
    });

    test('propagates ApiFailureError from CalendarSyncRepository', () async {
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(_user()));
      when(
        () => mockSyncRepo.connect(any()),
      ).thenThrow(ApiFailureError('api error'));

      await expectLater(
        () => makeConnectUseCase()(),
        throwsA(isA<ApiFailureError>()),
      );
    });

    test('does not call connect when user document is missing', () async {
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer((_) => Stream.value(null));

      try {
        await makeConnectUseCase()();
      } on StateError {
        // expected
      }

      verifyNever(() => mockSyncRepo.connect(any()));
    });

    test('reads only the first emission from the user stream', () async {
      // Stream has multiple emissions; only the first should be consumed.
      when(
        () => mockUserRepo.watchUser(any()),
      ).thenAnswer(
        (_) => Stream.fromIterable([_user(email: 'first@mail.kmutt.ac.th')]),
      );
      when(
        () => mockSyncRepo.connect('first@mail.kmutt.ac.th'),
      ).thenAnswer((_) async {});

      await makeConnectUseCase()();

      verify(() => mockSyncRepo.connect('first@mail.kmutt.ac.th')).called(1);
    });
  });

  // ── SyncGCalUseCase ──────────────────────────────────────────────────────────

  group('SyncGCalUseCase', () {
    late SyncGCalUseCase useCase;

    setUp(() {
      useCase = SyncGCalUseCase(mockSyncRepo);
    });

    test('delegates call() to CalendarSyncRepository.syncSessions', () async {
      final sessions = [_session()];
      when(
        () => mockSyncRepo.syncSessions(sessions),
      ).thenAnswer((_) async => _syncResult());

      await useCase(sessions);

      verify(() => mockSyncRepo.syncSessions(sessions)).called(1);
    });

    test('returns SyncResult from repository unchanged', () async {
      final expected = _syncResult(synced: 3, failed: 1);
      final sessions = [
        _session(id: 's1'),
        _session(id: 's2'),
        _session(id: 's3'),
        _session(id: 's4'),
      ];
      when(
        () => mockSyncRepo.syncSessions(sessions),
      ).thenAnswer((_) async => expected);

      final result = await useCase(sessions);

      expect(result.syncedCount, 3);
      expect(result.failedCount, 1);
      expect(result.syncedAt, expected.syncedAt);
    });

    test('passes empty session list to repository without error', () async {
      when(
        () => mockSyncRepo.syncSessions(const []),
      ).thenAnswer((_) async => _syncResult(synced: 0));

      final result = await useCase(const []);

      expect(result.syncedCount, 0);
      expect(result.failedCount, 0);
    });

    test('propagates ApiFailureError from repository', () async {
      when(
        () => mockSyncRepo.syncSessions(any()),
      ).thenThrow(ApiFailureError('sync failed: 500'));

      await expectLater(
        () => useCase([_session()]),
        throwsA(isA<ApiFailureError>()),
      );
    });

    test('propagates CancelledError when no current session', () async {
      when(
        () => mockSyncRepo.syncSessions(any()),
      ).thenThrow(CancelledError());

      await expectLater(
        () => useCase([_session()]),
        throwsA(isA<CancelledError>()),
      );
    });

    test('calls syncSessions exactly once per invocation', () async {
      final sessions = [_session(id: 'a'), _session(id: 'b')];
      when(
        () => mockSyncRepo.syncSessions(sessions),
      ).thenAnswer((_) async => _syncResult(synced: 2));

      await useCase(sessions);

      verify(() => mockSyncRepo.syncSessions(sessions)).called(1);
    });
  });

  // ── DisconnectGCalUseCase ────────────────────────────────────────────────────

  group('DisconnectGCalUseCase', () {
    late DisconnectGCalUseCase useCase;

    setUp(() {
      useCase = DisconnectGCalUseCase(mockSyncRepo);
    });

    test('delegates call() to CalendarSyncRepository.disconnect', () async {
      when(
        () => mockSyncRepo.disconnect(),
      ).thenAnswer((_) async {});

      await useCase();

      verify(() => mockSyncRepo.disconnect()).called(1);
    });

    test('calls disconnect exactly once per invocation', () async {
      when(
        () => mockSyncRepo.disconnect(),
      ).thenAnswer((_) async {});

      await useCase();

      verify(() => mockSyncRepo.disconnect()).called(1);
    });

    test('propagates exceptions from repository disconnect()', () async {
      when(
        () => mockSyncRepo.disconnect(),
      ).thenThrow(ApiFailureError('revoke failed'));

      await expectLater(
        () => useCase(),
        throwsA(isA<ApiFailureError>()),
      );
    });

    test('completes normally when disconnect() succeeds', () async {
      when(
        () => mockSyncRepo.disconnect(),
      ).thenAnswer((_) async {});

      await expectLater(useCase(), completes);
    });

    test('does not call connect or syncSessions', () async {
      when(
        () => mockSyncRepo.disconnect(),
      ).thenAnswer((_) async {});

      await useCase();

      verifyNever(() => mockSyncRepo.connect(any()));
      verifyNever(() => mockSyncRepo.syncSessions(any()));
    });
  });
}
