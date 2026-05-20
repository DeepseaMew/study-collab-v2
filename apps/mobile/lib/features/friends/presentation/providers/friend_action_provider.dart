import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/domain/usecases/accept_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/decline_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/send_friend_request_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/unfriend_usecase.dart';
import 'package:mobile/features/friends/domain/usecases/withdraw_friend_request_usecase.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'friend_action_provider.g.dart';

/// Async notifier that owns all mutating friend actions.
///
/// Exposes five action methods that wrap the corresponding use cases. Each
/// method sets state to loading while the operation is in flight and to an
/// error on failure. On success the notifier returns to the idle null state so
/// callers can check for error vs. null to determine outcome.
///
/// No Firestore types appear here — all calls delegate through use cases and
/// the repository interface.
@riverpod
class FriendActionNotifier extends _$FriendActionNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Sends a friend request from [currentUid] to [targetUid].
  Future<void> sendRequest({
    required String currentUid,
    required String targetUid,
  }) async {
    state = const AsyncLoading();
    try {
      await SendFriendRequestUseCase(
        ref.read(friendsRepositoryProvider),
      ).execute(currentUid: currentUid, targetUid: targetUid);
      appLogger.info(AnalyticsEvents.friendRequestSent);
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      appLogger.error(
        'sendRequest failed',
        exception: e,
        stackTrace: st,
        extra: {'type': e.runtimeType.toString()},
      );
      state = AsyncError(e, st);
    } catch (e, st) {
      appLogger.error(
        'sendRequest unexpected error',
        exception: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }

  /// Accepts the pending request sent by [initiatorUid] to [currentUid].
  Future<void> acceptRequest({
    required String currentUid,
    required String initiatorUid,
  }) async {
    state = const AsyncLoading();
    try {
      await AcceptFriendRequestUseCase(
        ref.read(friendsRepositoryProvider),
      ).execute(currentUid: currentUid, initiatorUid: initiatorUid);
      appLogger.info(AnalyticsEvents.friendRequestAccepted);
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      appLogger.error(
        'acceptRequest failed',
        exception: e,
        stackTrace: st,
        extra: {'type': e.runtimeType.toString()},
      );
      state = AsyncError(e, st);
    } catch (e, st) {
      appLogger.error(
        'acceptRequest unexpected error',
        exception: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }

  /// Declines the pending request sent by [initiatorUid] to [currentUid].
  Future<void> declineRequest({
    required String currentUid,
    required String initiatorUid,
  }) async {
    state = const AsyncLoading();
    try {
      await DeclineFriendRequestUseCase(
        ref.read(friendsRepositoryProvider),
      ).execute(currentUid: currentUid, initiatorUid: initiatorUid);
      appLogger.info(AnalyticsEvents.friendRequestDeclined);
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      appLogger.error(
        'declineRequest failed',
        exception: e,
        stackTrace: st,
        extra: {'type': e.runtimeType.toString()},
      );
      state = AsyncError(e, st);
    } catch (e, st) {
      appLogger.error(
        'declineRequest unexpected error',
        exception: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }

  /// Withdraws the outgoing request sent by [currentUid] to [targetUid].
  Future<void> withdrawRequest({
    required String currentUid,
    required String targetUid,
  }) async {
    state = const AsyncLoading();
    try {
      await WithdrawFriendRequestUseCase(
        ref.read(friendsRepositoryProvider),
      ).execute(currentUid: currentUid, targetUid: targetUid);
      appLogger.info(AnalyticsEvents.friendRequestWithdrawn);
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      appLogger.error(
        'withdrawRequest failed',
        exception: e,
        stackTrace: st,
        extra: {'type': e.runtimeType.toString()},
      );
      state = AsyncError(e, st);
    } catch (e, st) {
      appLogger.error(
        'withdrawRequest unexpected error',
        exception: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }

  /// Removes the friendship between [currentUid] and [friendUid].
  Future<void> unfriend({
    required String currentUid,
    required String friendUid,
  }) async {
    state = const AsyncLoading();
    try {
      await UnfriendUseCase(
        ref.read(friendsRepositoryProvider),
      ).execute(currentUid: currentUid, friendUid: friendUid);
      appLogger.info(AnalyticsEvents.friendUnfriended);
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      appLogger.error(
        'unfriend failed',
        exception: e,
        stackTrace: st,
        extra: {'type': e.runtimeType.toString()},
      );
      state = AsyncError(e, st);
    } catch (e, st) {
      appLogger.error(
        'unfriend unexpected error',
        exception: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }
}
