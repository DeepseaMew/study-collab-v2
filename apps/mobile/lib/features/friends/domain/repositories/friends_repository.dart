import 'package:mobile/features/friends/domain/entities/friend_entity.dart';

/// Abstract repository interface for Friends operations.
///
/// All methods accept and return plain Dart types only — no Firestore types
/// cross this boundary (ADR 0004 constraint).
///
/// Implementations live in `data/repositories/`.
abstract interface class FriendsRepository {
  // ── Streams ──────────────────────────────────────────────────────────────

  /// Watches the accepted friends of [uid], ordered by `updatedAt` descending.
  ///
  /// Uses Index 10 from ADR 0001 Amendment 2.
  Stream<List<FriendEntity>> watchFriends(String uid);

  /// Watches pending friend requests received by [uid] (where
  /// `initiatorUid != uid`).
  Stream<List<FriendEntity>> watchIncomingRequests(String uid);

  /// Watches pending friend requests sent by [uid] (where
  /// `initiatorUid == uid`).
  Stream<List<FriendEntity>> watchOutgoingRequests(String uid);

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Sends a friend request from [currentUid] to [targetUid].
  ///
  /// Writes a `WriteBatch` with two `status == 'pending'` documents —
  /// one on each side of the bidirectional friendship (ADR 0001).
  ///
  /// The batch omits `friendDisplayName` and `friendPhotoUrl` at creation
  /// time (ADR 0004 Firestore rules require those fields to be absent on
  /// create and only present after accept).
  Future<void> sendRequest(String currentUid, String targetUid);

  /// Accepts a pending friend request where [initiatorUid] sent the request
  /// to [currentUid].
  ///
  /// The `WriteBatch` updates `status = 'accepted'` on both documents and
  /// writes denormalized `friendDisplayName` and `friendPhotoUrl` on each
  /// side (ADR 0004 sub-decision 1). Both user documents are read once to
  /// source the display fields before the batch commits.
  Future<void> acceptRequest(String currentUid, String initiatorUid);

  /// Declines a pending friend request where [initiatorUid] sent the request
  /// to [currentUid].
  ///
  /// The `WriteBatch` deletes both pending documents atomically.
  Future<void> declineRequest(String currentUid, String initiatorUid);

  /// Withdraws an outgoing friend request sent by [currentUid] to [targetUid].
  ///
  /// The `WriteBatch` deletes both pending documents atomically.
  Future<void> withdrawRequest(String currentUid, String targetUid);

  /// Removes an accepted friendship between [currentUid] and [friendUid].
  ///
  /// The `WriteBatch` deletes both accepted documents atomically.
  Future<void> unfriend(String currentUid, String friendUid);
}
