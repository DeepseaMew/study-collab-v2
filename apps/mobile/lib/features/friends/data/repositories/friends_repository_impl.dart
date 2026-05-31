import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';
import 'package:mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/usecases/create_notification_usecase.dart';

/// Firestore implementation of [FriendsRepository].
///
/// Owns the display-field sourcing logic required for the accept-request batch:
/// reads both users' documents once to supply `friendDisplayName` and
/// `friendPhotoUrl` before delegating the batch to [FriendsDatasource].
///
/// Notification triggers 1 (friend_request) and 2 (friend_accepted) are
/// fire-and-forget: failure must never block the primary friend action (ADR 0013).
///
/// No Firestore types appear at the [FriendsRepository] interface boundary.
class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._datasource)
    : _notifDatasource = NotificationRemoteDatasource.withDefaultFirestore();

  @visibleForTesting
  FriendsRepositoryImpl.withNotificationDatasource(
    FriendsDatasource datasource,
    NotificationRemoteDatasource notificationDatasource,
  ) : _datasource = datasource,
      _notifDatasource = notificationDatasource;

  final FriendsDatasource _datasource;
  final NotificationRemoteDatasource _notifDatasource;

  @override
  Stream<List<FriendEntity>> watchFriends(String uid) {
    return _datasource
        .watchFriends(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<List<FriendEntity>> watchIncomingRequests(String uid) {
    return _datasource
        .watchIncomingRequests(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<List<FriendEntity>> watchOutgoingRequests(String uid) {
    return _datasource
        .watchOutgoingRequests(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<void> sendRequest(String currentUid, String targetUid) async {
    // Read the current user's document to source actorDisplayName (R1 resolution).
    final currentData = await _datasource.readUserDoc(currentUid);
    final actorDisplayName = (currentData['displayName'] as String? ?? '')
        .trim();

    await _datasource.sendRequest(currentUid, targetUid);
    appLogger.info('Friend request sent via repository');

    // Trigger 1: fire-and-forget notification to recipient (ADR 0013).
    _fireNotification(
      CreateNotificationParams(
        recipientUid: targetUid,
        actorUid: currentUid,
        actorDisplayName: actorDisplayName.isNotEmpty
            ? actorDisplayName
            : 'A user',
        type: NotificationType.friendRequest,
      ),
    );
  }

  @override
  Future<void> acceptRequest(String currentUid, String initiatorUid) async {
    // Read both user documents once to source denormalized display fields
    // (ADR 0004 sub-decision 1: accept batch writes friendDisplayName and
    // friendPhotoUrl on both sides).
    final currentData = await _datasource.readUserDoc(currentUid);
    final initiatorData = await _datasource.readUserDoc(initiatorUid);

    final currentDisplayName = (currentData['displayName'] as String?) ?? '';
    final currentPhotoUrl = currentData['photoUrl'] as String?;
    final initiatorDisplayName =
        (initiatorData['displayName'] as String?) ?? '';
    final initiatorPhotoUrl = initiatorData['photoUrl'] as String?;

    if (currentDisplayName.isEmpty) {
      appLogger.warning(
        'acceptRequest: currentUser displayName is empty; denormalized field will be blank',
      );
    }
    if (initiatorDisplayName.isEmpty) {
      appLogger.warning(
        'acceptRequest: initiator displayName is empty; denormalized field will be blank',
      );
    }

    await _datasource.acceptRequest(
      currentUid: currentUid,
      initiatorUid: initiatorUid,
      currentDisplayName: currentDisplayName,
      currentPhotoUrl: currentPhotoUrl,
      initiatorDisplayName: initiatorDisplayName,
      initiatorPhotoUrl: initiatorPhotoUrl,
    );
    appLogger.info('Friend request accepted via repository');

    // Trigger 2: fire-and-forget notification to the original initiator (ADR 0013).
    _fireNotification(
      CreateNotificationParams(
        recipientUid: initiatorUid,
        actorUid: currentUid,
        actorDisplayName: currentDisplayName.isNotEmpty
            ? currentDisplayName
            : 'A user',
        type: NotificationType.friendAccepted,
      ),
    );
  }

  @override
  Future<void> declineRequest(String currentUid, String initiatorUid) async {
    await _datasource.declineRequest(currentUid, initiatorUid);
    appLogger.info('Friend request declined via repository');
  }

  @override
  Future<void> withdrawRequest(String currentUid, String targetUid) async {
    await _datasource.withdrawRequest(currentUid, targetUid);
    appLogger.info('Friend request withdrawn via repository');
  }

  @override
  Future<void> unfriend(String currentUid, String friendUid) async {
    if (currentUid == friendUid) {
      throw const ValidationException('Cannot unfriend yourself.');
    }
    await _datasource.unfriend(currentUid, friendUid);
    appLogger.info('Unfriend completed via repository');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fire-and-forget notification write. Failure is logged but never re-thrown
  /// so the primary friend action is never blocked (ADR 0013 trigger constraint).
  void _fireNotification(CreateNotificationParams params) {
    _notifDatasource
        .createNotification(
          recipientUid: params.recipientUid,
          actorUid: params.actorUid,
          actorDisplayName: params.actorDisplayName,
          type: params.type,
          sessionId: params.sessionId,
          sessionTitle: params.sessionTitle,
        )
        .catchError((Object e, StackTrace st) {
          appLogger.error(
            'FriendsRepositoryImpl: notification trigger failed (fire-and-forget)',
            exception: e,
            stackTrace: st,
            extra: {'type': params.type.toFirestoreString()},
          );
        });
  }
}
