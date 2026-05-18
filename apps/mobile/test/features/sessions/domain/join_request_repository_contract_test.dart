// Contract tests for JoinRequestRepository operations.
//
// Covers: watchRequests, submitRequest, approveRequest, declineRequest,
// withdrawRequest, joinWithPin — the full ADR 0003 interface surface.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockJoinRequestRepository extends Mock
    implements JoinRequestRepository {}

JoinRequestEntity _req({String uid = 'user-1', String displayName = 'User 1'}) {
  return JoinRequestEntity(
    uid: uid,
    displayName: displayName,
    requestedAt: DateTime(2026, 5, 18, 10),
  );
}

void main() {
  late _MockJoinRequestRepository repo;

  setUp(() {
    repo = _MockJoinRequestRepository();
    registerFallbackValue(_req());
  });

  group('watchRequests', () {
    test('emits list of requests', () {
      final requests = [_req(uid: 'u1'), _req(uid: 'u2')];
      when(() => repo.watchRequests('sess-1'))
          .thenAnswer((_) => Stream.value(requests));

      expect(repo.watchRequests('sess-1'), emits(requests));
    });

    test('emits empty list when no pending requests', () {
      when(() => repo.watchRequests('sess-1'))
          .thenAnswer((_) => Stream.value(const []));

      expect(repo.watchRequests('sess-1'), emits(isEmpty));
    });
  });

  group('submitRequest', () {
    test('delegates correct args to repository', () async {
      final req = _req();
      when(() => repo.submitRequest(any(), any())).thenAnswer((_) async {});

      await repo.submitRequest('sess-1', req);

      verify(() => repo.submitRequest('sess-1', req)).called(1);
    });

    test('propagates DataException on Firestore failure', () async {
      when(() => repo.submitRequest(any(), any()))
          .thenThrow(const DataException('write failed'));

      expect(
        () => repo.submitRequest('sess-1', _req()),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('approveRequest', () {
    test('delegates correct args to repository', () async {
      when(() => repo.approveRequest(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.approveRequest('sess-1', 'host-1', 'user-1');

      verify(() => repo.approveRequest('sess-1', 'host-1', 'user-1')).called(1);
    });

    test('propagates AuthorisationException when caller is not host', () async {
      when(() => repo.approveRequest(any(), any(), any()))
          .thenThrow(const AuthorisationException('not host'));

      expect(
        () => repo.approveRequest('sess-1', 'not-host', 'user-1'),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });

  group('declineRequest', () {
    test('delegates correct args to repository', () async {
      when(() => repo.declineRequest(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.declineRequest('sess-1', 'host-1', 'user-1');

      verify(() => repo.declineRequest('sess-1', 'host-1', 'user-1')).called(1);
    });

    test('propagates AuthorisationException when caller is not host', () async {
      when(() => repo.declineRequest(any(), any(), any()))
          .thenThrow(const AuthorisationException('not host'));

      expect(
        () => repo.declineRequest('sess-1', 'not-host', 'user-1'),
        throwsA(isA<AuthorisationException>()),
      );
    });
  });

  group('withdrawRequest', () {
    test('delegates correct args to repository', () async {
      when(() => repo.withdrawRequest(any(), any())).thenAnswer((_) async {});

      await repo.withdrawRequest('sess-1', 'user-1');

      verify(() => repo.withdrawRequest('sess-1', 'user-1')).called(1);
    });

    test('propagates NotFoundException when request does not exist', () async {
      when(() => repo.withdrawRequest(any(), any()))
          .thenThrow(const NotFoundException('request not found'));

      expect(
        () => repo.withdrawRequest('sess-1', 'user-1'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('joinWithPin', () {
    test('delegates correct args to repository', () async {
      when(() => repo.joinWithPin(any(), any(), any()))
          .thenAnswer((_) async {});

      await repo.joinWithPin('sess-1', _req(), 'abcd');

      verify(() => repo.joinWithPin('sess-1', _req(), 'abcd')).called(1);
    });

    test('throws InvalidPinException when PIN is wrong', () async {
      when(() => repo.joinWithPin(any(), any(), any()))
          .thenThrow(const InvalidPinException('Incorrect PIN'));

      expect(
        () => repo.joinWithPin('sess-1', _req(), 'wrong'),
        throwsA(isA<InvalidPinException>()),
      );
    });

    test('throws DataException when Firestore write fails', () async {
      when(() => repo.joinWithPin(any(), any(), any()))
          .thenThrow(const DataException('network error'));

      expect(
        () => repo.joinWithPin('sess-1', _req(), 'abcd'),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('JoinRequestEntity equality', () {
    test('identical requests are equal', () {
      final r1 = _req(uid: 'u1');
      final r2 = _req(uid: 'u1');
      expect(r1, equals(r2));
    });

    test('requests with different UIDs are not equal', () {
      final r1 = _req(uid: 'u1');
      final r2 = _req(uid: 'u2');
      expect(r1, isNot(equals(r2)));
    });
  });
}
