import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Firestore implementation of [FriendsRepository].
///
/// Owns the display-field sourcing logic required for the accept-request batch:
/// reads both users' documents once to supply `friendDisplayName` and
/// `friendPhotoUrl` before delegating the batch to [FriendsDatasource].
///
/// No Firestore types appear at the [FriendsRepository] interface boundary.
class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._datasource);

  final FriendsDatasource _datasource;

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
    await _datasource.sendRequest(currentUid, targetUid);
    appLogger.info('Friend request sent via repository');
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
}
