// Contract tests for SessionRepository operations.
//
// These tests verify that a mock implementation of SessionRepository receives
// the correct calls with the correct arguments. They exercise the full
// interface surface defined in ADR 0003:
//   - watchSession
//   - watchPublicSessions
//   - watchMembers
//   - createSession (with and without PIN)
//   - editSession
//   - deleteSession
//   - endSession
//   - leaveSession (including host guard — SEC-002)
//   - fetchPin (host-only PIN retrieval — SEC-001)

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

SessionEntity _stub({
  String id = 'sess-1',
  String hostUid = 'host-1',
  String visibility = 'public',
  int capacity = 10,
  List<String> memberUids = const [],
  String status = 'scheduled',
}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: hostUid,
    hostFaculty: 'Engineering',
    title: 'Data Structures Study Group',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: visibility,
    memberUids: memberUids,
    noteCount: 0,
    status: status,
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: capacity,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

UserEntity _userStub(String uid) => UserEntity(
      uid: uid,
      displayName: 'User $uid',
      fullName: 'Full Name $uid',
      email: '$uid@mail.kmutt.ac.th',
      hasHostedBefore: false,
      studentYear: 1,
      academicLevel: 'undergraduate',
      faculty: 'Engineering',
      profileScore: 0.0,
    );

void main() {
  late _MockSessionRepository repo;

  setUp(() {
    repo = _MockSessionRepository();
    registerFallbackValue(_stub());
  });

  group('watchSession', () {
    test('emits session entity when document exists', () {
      final session = _stub();
      when(() => repo.watchSession('sess-1')).thenAnswer(
        (_) => Stream.value(session),
      );

      expect(repo.watchSession('sess-1'), emits(session));
    });

    test('emits null when document does not exist', () {
      when(() => repo.watchSession('missing'))
          .thenAnswer((_) => Stream.value(null));

      expect(repo.watchSession('missing'), emits(null));
    });
  });

  group('watchPublicSessions', () {
    test('emits list of sessions', () {
      final sessions = [_stub(), _stub(id: 'sess-2')];
      when(() => repo.watchPublicSessions())
          .thenAnswer((_) => Stream.value(sessions));

      expect(repo.watchPublicSessions(), emits(sessions));
    });

    test('emits empty list when no public sessions exist', () {
      when(() => repo.watchPublicSessions())
          .thenAnswer((_) => Stream.value(const []));

      expect(repo.watchPublicSessions(), emits(isEmpty));
    });
  });

  group('watchMembers', () {
    test('emits list of user entities', () {
      final members = [_userStub('u1'), _userStub('u2')];
      when(() => repo.watchMembers('sess-1'))
          .thenAnswer((_) => Stream.value(members));

      expect(repo.watchMembers('sess-1'), emits(members));
    });
  });

  group('createSession', () {
    test('delegates to repository for public session', () async {
      final session = _stub();
      when(() => repo.createSession(any())).thenAnswer((_) async {});

      await repo.createSession(session);

      verify(() => repo.createSession(session)).called(1);
    });

    test('delegates to repository with plainTextPin for private session',
        () async {
      final session = _stub(visibility: 'private');
      when(
        () => repo.createSession(any(), plainTextPin: any(named: 'plainTextPin')),
      ).thenAnswer((_) async {});

      await repo.createSession(session, plainTextPin: 'abcd1234');

      verify(
        () => repo.createSession(session, plainTextPin: 'abcd1234'),
      ).called(1);
    });

    test('propagates DataException on Firestore failure', () async {
      when(() => repo.createSession(any()))
          .thenThrow(const DataException('write failed'));

      expect(
        () => repo.createSession(_stub()),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('editSession', () {
    test('delegates correct args to repository', () async {
      when(
        () => repo.editSession(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async {});

      await repo.editSession('sess-1', 'host-1', {'title': 'New Title'});

      verify(
        () => repo.editSession('sess-1', 'host-1', {'title': 'New Title'}),
      ).called(1);
    });

    test('propagates AuthorisationException when caller is not host', () async {
      when(
        () => repo.editSession(any(), any(), any()),
      ).thenThrow(const AuthorisationException('not host'));

      expect(
        () => repo.editSession('sess-1', 'not-host', {}),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });

  group('deleteSession', () {
    test('delegates correct args to repository', () async {
      when(() => repo.deleteSession(any(), any())).thenAnswer((_) async {});

      await repo.deleteSession('sess-1', 'host-1');

      verify(() => repo.deleteSession('sess-1', 'host-1')).called(1);
    });

    test('propagates AuthorisationException when not host', () async {
      when(() => repo.deleteSession(any(), any()))
          .thenThrow(const AuthorisationException('not host'));

      expect(
        () => repo.deleteSession('sess-1', 'other-uid'),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });

  group('endSession', () {
    test('delegates correct args to repository', () async {
      when(() => repo.endSession(any(), any())).thenAnswer((_) async {});

      await repo.endSession('sess-1', 'host-1');

      verify(() => repo.endSession('sess-1', 'host-1')).called(1);
    });

    test('propagates error on failure', () async {
      when(() => repo.endSession(any(), any()))
          .thenThrow(const DataException('Firestore error'));

      expect(
        () => repo.endSession('sess-1', 'host-1'),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('leaveSession', () {
    test('delegates correct args to repository', () async {
      when(() => repo.leaveSession(any(), any())).thenAnswer((_) async {});

      await repo.leaveSession('sess-1', 'member-uid');

      verify(() => repo.leaveSession('sess-1', 'member-uid')).called(1);
    });

    test('throws AuthorisationException when the host tries to leave', () async {
      when(() => repo.leaveSession(any(), any()))
          .thenThrow(const AuthorisationException('Host cannot leave'));

      expect(
        () => repo.leaveSession('sess-1', 'host-uid'),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });

  group('fetchPin', () {
    test('returns pin for the host caller', () async {
      when(() => repo.fetchPin(any(), any())).thenAnswer((_) async => 'abcd');

      final pin = await repo.fetchPin('sess-1', 'host-1');

      expect(pin, equals('abcd'));
    });

    test('returns null for a public session', () async {
      when(() => repo.fetchPin(any(), any())).thenAnswer((_) async => null);

      final pin = await repo.fetchPin('sess-1', 'host-1');

      expect(pin, isNull);
    });

    test('throws AuthorisationException when caller is not the host', () async {
      when(() => repo.fetchPin(any(), any()))
          .thenThrow(const AuthorisationException('Only the host may view the PIN.'));

      expect(
        () => repo.fetchPin('sess-1', 'non-host'),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });
}
