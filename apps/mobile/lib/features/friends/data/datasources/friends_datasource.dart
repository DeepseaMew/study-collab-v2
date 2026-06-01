import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/data/models/friend_model.dart';

/// Firestore data source for the `users/{uid}/friends` subcollection.
///
/// All path strings come from [FirestorePaths]. No path strings are inlined.
/// All [WriteBatch] construction is owned by this class — no Firestore types
/// escape into the repository implementation.
class FriendsDatasource {
  FriendsDatasource(this._firestore);

  /// Creates a [FriendsDatasource] wired to the default [FirebaseFirestore]
  /// instance. Use this factory from `@riverpod` repository providers so that
  /// presentation-layer files do not need to import `cloud_firestore` directly.
  factory FriendsDatasource.withDefaultFirestore() =>
      FriendsDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  // ── Helpers ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _friendsCol(String uid) =>
      _firestore.collection(FirestorePaths.userFriendsCollection(uid));

  DocumentReference<Map<String, dynamic>> _friendDoc(
    String uid,
    String friendUid,
  ) => _firestore.doc(FirestorePaths.userFriendDoc(uid, friendUid));

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.doc(FirestorePaths.userDoc(uid));

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Watches accepted friends of [uid], ordered by `updatedAt` descending.
  ///
  /// Uses Index 10 from ADR 0001 Amendment 2.
  Stream<List<FriendModel>> watchFriends(String uid) {
    return _friendsCol(uid)
        .where('status', isEqualTo: 'accepted')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  /// Watches pending requests received by [uid] (where `initiatorUid != uid`).
  Stream<List<FriendModel>> watchIncomingRequests(String uid) {
    return _friendsCol(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => _parseDocs(
            snap.docs,
          ).where((m) => m.initiatorUid != uid).toList(),
        );
  }

  /// Watches pending requests sent by [uid] (where `initiatorUid == uid`).
  Stream<List<FriendModel>> watchOutgoingRequests(String uid) {
    return _friendsCol(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => _parseDocs(
            snap.docs,
          ).where((m) => m.initiatorUid == uid).toList(),
        );
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Sends a friend request: writes two `status == 'pending'` documents
  /// atomically (one per side of the bidirectional friendship).
  ///
  /// Does NOT write `friendDisplayName` or `friendPhotoUrl` at creation time
  /// (ADR 0004 Firestore create rule prohibits those fields on create).
  Future<void> sendRequest(String currentUid, String targetUid) async {
    try {
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Current user's side: document at users/{currentUid}/friends/{targetUid}
      batch.set(_friendDoc(currentUid, targetUid), {
        'friendUid': targetUid,
        'status': 'pending',
        'initiatorUid': currentUid,
        'createdAt': now,
        'updatedAt': now,
      });

      // Target user's side: document at users/{targetUid}/friends/{currentUid}
      batch.set(_friendDoc(targetUid, currentUid), {
        'friendUid': currentUid,
        'status': 'pending',
        'initiatorUid': currentUid,
        'createdAt': now,
        'updatedAt': now,
      });

      await batch.commit();
      appLogger.info('Friend request batch committed');
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore sendRequest batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not send friend request: ${e.message}');
    }
  }

  /// Accepts a friend request: updates both documents to `status == 'accepted'`
  /// and writes denormalized display fields on each side.
  ///
  /// [currentUid] is the user accepting; [initiatorUid] sent the request.
  /// [currentDisplayName] and [currentPhotoUrl] are the acceptor's display data.
  /// [initiatorDisplayName] and [initiatorPhotoUrl] are the initiator's display data.
  Future<void> acceptRequest({
    required String currentUid,
    required String initiatorUid,
    required String currentDisplayName,
    String? currentPhotoUrl,
    required String initiatorDisplayName,
    String? initiatorPhotoUrl,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Initiator's doc gets the acceptor's (current user's) display data.
      batch.update(_friendDoc(initiatorUid, currentUid), {
        'status': 'accepted',
        'updatedAt': now,
        'friendDisplayName': currentDisplayName,
        'friendPhotoUrl': currentPhotoUrl,
      });

      // Acceptor's doc gets the initiator's display data.
      batch.update(_friendDoc(currentUid, initiatorUid), {
        'status': 'accepted',
        'updatedAt': now,
        'friendDisplayName': initiatorDisplayName,
        'friendPhotoUrl': initiatorPhotoUrl,
      });

      await batch.commit();
      appLogger.info('Accept request batch committed');
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore acceptRequest batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not accept friend request: ${e.message}');
    }
  }

  /// Declines a friend request: deletes both pending documents atomically.
  Future<void> declineRequest(String currentUid, String initiatorUid) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, initiatorUid));
      batch.delete(_friendDoc(initiatorUid, currentUid));
      await batch.commit();
      appLogger.info('Decline request batch committed');
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore declineRequest batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not decline friend request: ${e.message}');
    }
  }

  /// Withdraws an outgoing request: deletes both pending documents atomically.
  Future<void> withdrawRequest(String currentUid, String targetUid) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, targetUid));
      batch.delete(_friendDoc(targetUid, currentUid));
      await batch.commit();
      appLogger.info('Withdraw request batch committed');
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore withdrawRequest batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not withdraw friend request: ${e.message}');
    }
  }

  /// Unfriends: deletes both accepted documents atomically.
  Future<void> unfriend(String currentUid, String friendUid) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, friendUid));
      batch.delete(_friendDoc(friendUid, currentUid));
      await batch.commit();
      appLogger.info('Unfriend batch committed');
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore unfriend batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not unfriend: ${e.message}');
    }
  }

  /// Reads a user document to source display fields for accept-request
  /// denormalization. Returns an empty map when the document is missing.
  Future<Map<String, dynamic>> readUserDoc(String uid) async {
    try {
      final snap = await _userDoc(uid).get();
      return snap.data() ?? {};
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore readUserDoc failed in FriendsDatasource',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not read user document: ${e.message}');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Converts Firestore [Timestamp] values for `createdAt` and `updatedAt` to
  /// millisecondsSinceEpoch so that [FriendModel.fromJson] can use the
  /// [_EpochConverter] without importing [cloud_firestore] in the model.
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    for (final key in const ['createdAt', 'updatedAt']) {
      final value = result[key];
      if (value is Timestamp) {
        result[key] = value.millisecondsSinceEpoch;
      }
    }
    return result;
  }

  List<FriendModel> _parseDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            return FriendModel.fromJson(_convertTimestamps(doc.data()));
          } catch (e, st) {
            appLogger.error(
              'Failed to parse friend document',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<FriendModel>()
        .toList();
  }
}
