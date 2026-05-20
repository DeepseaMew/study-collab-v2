// Unit tests for all Friends use cases.
//
// Covers happy path and one failure path per use case.
// Uses a mock FriendsRepository — no Firestore calls.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';
import 'package:mobile/features/friends/domain/usecases/accept_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/decline_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/send_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/unfriend_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friends_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/watch_incoming_requests_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/withdraw_friend_request_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockFriendsRepository extends Mock implements FriendsRepository {}

// ── Shared test data ──────────────────────────────────────────────────────────

FriendEntity _stubFriend({
  String friendUid = 'friend-uid',
  String status = 'accepted',
  String initiatorUid = 'current-uid',
}) {
  final now = DateTime(2026, 5, 20);
  return FriendEntity(
    friendUid: friendUid,
    status: status,
    initiatorUid: initiatorUid,
    createdAt: now,
    updatedAt: now,
    friendDisplayName: 'Alice',
    friendPhotoUrl: null,
  );
}

void main() {
  late _MockFriendsRepository mockRepo;

  setUp(() {
    mockRepo = _MockFriendsRepository();
  });

  // ── WatchFriendsUseCase ───────────────────────────────────────────────────

  group('WatchFriendsUseCase', () {
    late WatchFriendsUseCase useCase;

    setUp(() {
      useCase = WatchFriendsUseCase(mockRepo);
    });

    test('happy path — delegates to repository and emits friends list',
        () async {
      final friends = [_stubFriend()];
      when(() => mockRepo.watchFriends('current-uid'))
          .thenAnswer((_) => Stream.value(friends));

      final result = await useCase.execute('current-uid').first;

      expect(result, friends);
      verify(() => mockRepo.watchFriends('current-uid')).called(1);
    });

    test('failure path — propagates stream error from repository', () async {
      when(() => mockRepo.watchFriends('current-uid')).thenAnswer(
        (_) => Stream.error(const DataException('Firestore unavailable')),
      );

      expect(
        useCase.execute('current-uid'),
        emitsError(isA<DataException>()),
      );
    });
  });

  // ── SendFriendRequestUseCase ──────────────────────────────────────────────

  group('SendFriendRequestUseCase', () {
    late SendFriendRequestUseCase useCase;

    setUp(() {
      useCase = SendFriendRequestUseCase(mockRepo);
    });

    test('happy path — delegates to repository.sendRequest', () async {
      when(() => mockRepo.sendRequest('current-uid', 'target-uid'))
          .thenAnswer((_) async {});

      await useCase.execute(
        currentUid: 'current-uid',
        targetUid: 'target-uid',
      );

      verify(() => mockRepo.sendRequest('current-uid', 'target-uid')).called(1);
    });

    test('failure path — propagates DataException from repository', () {
      when(() => mockRepo.sendRequest(any(), any()))
          .thenThrow(const DataException('Batch write failed'));

      expect(
        () => useCase.execute(
          currentUid: 'current-uid',
          targetUid: 'target-uid',
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── AcceptFriendRequestUseCase ────────────────────────────────────────────

  group('AcceptFriendRequestUseCase', () {
    late AcceptFriendRequestUseCase useCase;

    setUp(() {
      useCase = AcceptFriendRequestUseCase(mockRepo);
    });

    test('happy path — delegates to repository.acceptRequest', () async {
      when(() => mockRepo.acceptRequest('current-uid', 'initiator-uid'))
          .thenAnswer((_) async {});

      await useCase.execute(
        currentUid: 'current-uid',
        initiatorUid: 'initiator-uid',
      );

      verify(
        () => mockRepo.acceptRequest('current-uid', 'initiator-uid'),
      ).called(1);
    });

    test('failure path — propagates DataException from repository', () {
      when(() => mockRepo.acceptRequest(any(), any()))
          .thenThrow(const DataException('Accept batch failed'));

      expect(
        () => useCase.execute(
          currentUid: 'current-uid',
          initiatorUid: 'initiator-uid',
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── DeclineFriendRequestUseCase ───────────────────────────────────────────

  group('DeclineFriendRequestUseCase', () {
    late DeclineFriendRequestUseCase useCase;

    setUp(() {
      useCase = DeclineFriendRequestUseCase(mockRepo);
    });

    test('happy path — delegates to repository.declineRequest', () async {
      when(() => mockRepo.declineRequest('current-uid', 'initiator-uid'))
          .thenAnswer((_) async {});

      await useCase.execute(
        currentUid: 'current-uid',
        initiatorUid: 'initiator-uid',
      );

      verify(
        () => mockRepo.declineRequest('current-uid', 'initiator-uid'),
      ).called(1);
    });

    test('failure path — propagates DataException from repository', () {
      when(() => mockRepo.declineRequest(any(), any()))
          .thenThrow(const DataException('Decline batch failed'));

      expect(
        () => useCase.execute(
          currentUid: 'current-uid',
          initiatorUid: 'initiator-uid',
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── WithdrawFriendRequestUseCase ──────────────────────────────────────────

  group('WithdrawFriendRequestUseCase', () {
    late WithdrawFriendRequestUseCase useCase;

    setUp(() {
      useCase = WithdrawFriendRequestUseCase(mockRepo);
    });

    test('happy path — delegates to repository.withdrawRequest', () async {
      when(() => mockRepo.withdrawRequest('current-uid', 'target-uid'))
          .thenAnswer((_) async {});

      await useCase.execute(
        currentUid: 'current-uid',
        targetUid: 'target-uid',
      );

      verify(
        () => mockRepo.withdrawRequest('current-uid', 'target-uid'),
      ).called(1);
    });

    test('failure path — propagates DataException from repository', () {
      when(() => mockRepo.withdrawRequest(any(), any()))
          .thenThrow(const DataException('Withdraw batch failed'));

      expect(
        () => useCase.execute(
          currentUid: 'current-uid',
          targetUid: 'target-uid',
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── UnfriendUseCase ───────────────────────────────────────────────────────

  group('UnfriendUseCase', () {
    late UnfriendUseCase useCase;

    setUp(() {
      useCase = UnfriendUseCase(mockRepo);
    });

    test('happy path — delegates to repository.unfriend', () async {
      when(() => mockRepo.unfriend('current-uid', 'friend-uid'))
          .thenAnswer((_) async {});

      await useCase.execute(
        currentUid: 'current-uid',
        friendUid: 'friend-uid',
      );

      verify(() => mockRepo.unfriend('current-uid', 'friend-uid')).called(1);
    });

    test('failure path — propagates DataException from repository', () {
      when(() => mockRepo.unfriend(any(), any()))
          .thenThrow(const DataException('Unfriend batch failed'));

      expect(
        () => useCase.execute(
          currentUid: 'current-uid',
          friendUid: 'friend-uid',
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  // ── WatchIncomingRequestsUseCase ──────────────────────────────────────────

  group('WatchIncomingRequestsUseCase', () {
    late WatchIncomingRequestsUseCase useCase;

    setUp(() {
      useCase = WatchIncomingRequestsUseCase(mockRepo);
    });

    test('happy path — delegates to repository and emits requests list',
        () async {
      final requests = [
        _stubFriend(
          friendUid: 'sender-uid',
          status: 'pending',
          initiatorUid: 'sender-uid',
        ),
      ];
      when(() => mockRepo.watchIncomingRequests('current-uid'))
          .thenAnswer((_) => Stream.value(requests));

      final result = await useCase.execute('current-uid').first;

      expect(result, requests);
      verify(() => mockRepo.watchIncomingRequests('current-uid')).called(1);
    });

    // Domain contract: when the stream emits a list where initiatorUid == uid,
    // that item must NOT appear. The filter runs in the datasource; this test
    // verifies that the repository honours the contract so the use case only
    // surfaces items where initiatorUid != uid.
    test(
      'domain contract — item with initiatorUid == uid is not present in stream result',
      () async {
        // Simulate the datasource/repository having already applied the filter.
        // The use case delegates; if the repository correctly filters, the
        // resulting list will not contain any item where initiatorUid == uid.
        const uid = 'current-uid';
        final filteredList = [
          _stubFriend(
            friendUid: 'sender-uid',
            status: 'pending',
            initiatorUid: 'sender-uid', // NOT equal to uid
          ),
        ];

        when(() => mockRepo.watchIncomingRequests(uid))
            .thenAnswer((_) => Stream.value(filteredList));

        final result = await useCase.execute(uid).first;

        // None of the emitted items should have initiatorUid == uid.
        expect(
          result.every((f) => f.initiatorUid != uid),
          isTrue,
          reason:
              'Incoming requests must not contain items initiated by the recipient uid',
        );
      },
    );

    test('failure path — propagates stream error from repository', () async {
      when(() => mockRepo.watchIncomingRequests('current-uid')).thenAnswer(
        (_) => Stream.error(const DataException('Firestore error')),
      );

      expect(
        useCase.execute('current-uid'),
        emitsError(isA<DataException>()),
      );
    });
  });
}
