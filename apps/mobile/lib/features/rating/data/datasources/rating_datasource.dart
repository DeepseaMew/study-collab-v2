import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/rating/data/models/rating_model.dart';

/// Low-level Firestore operations for the Rating feature.
///
/// All Firestore path strings come from [FirestorePaths].
/// No domain types cross this boundary — callers in [RatingRepositoryImpl]
/// handle model-to-entity conversion.
class RatingDatasource {
  RatingDatasource(this._firestore, this._crashlytics);

  final FirebaseFirestore _firestore;
  // Null on Web — Crashlytics is not supported on the Web platform.
  final FirebaseCrashlytics? _crashlytics;

  /// Atomically writes the rating document and updates the ratee's profileScore.
  Future<void> writeRatingBatch(
    String sessionId,
    String currentUid,
    String rateeUid,
    double newProfileScore,
  ) async {
    appLogger.debug('rating: writing batch', extra: {'sessionId': sessionId});
    final batch = _firestore.batch();

    final ratingRef = _firestore.doc(
      FirestorePaths.rating(sessionId, currentUid, rateeUid),
    );
    batch.set(ratingRef, {
      'ratingId': '${currentUid}_$rateeUid',
      'raterUid': currentUid,
      'rateeUid': rateeUid,
      'liked': true,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    final userRef = _firestore.doc(FirestorePaths.userDoc(rateeUid));
    batch.update(userRef, {'profileScore': newProfileScore});

    try {
      await batch.commit();
      appLogger.info(
        'rating: batch committed',
        extra: {'sessionId': sessionId},
      );
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'rating: batch commit failed',
        exception: e,
        stackTrace: st,
        extra: {'errorCode': e.code, 'sessionId': sessionId},
      );
      await _crashlytics?.recordError(e, st);
      rethrow;
    }
  }

  /// Returns the total number of thumbs-up ratings received by [rateeUid].
  Future<int> countThumbsUpReceived(String rateeUid) async {
    final snapshot = await _firestore
        .collectionGroup('ratings')
        .where('rateeUid', isEqualTo: rateeUid)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Returns the number of ended sessions that [uid] is a member of.
  Future<int> countEndedSessionsJoined(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.sessionsCollection)
        .where('memberUids', arrayContains: uid)
        .where('status', isEqualTo: 'ended')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Streams all ratings for [sessionId] ordered by ratedAt descending.
  Stream<List<RatingModel>> watchSessionRatings(String sessionId) {
    return _firestore
        .collection(FirestorePaths.ratings(sessionId))
        .orderBy('ratedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RatingModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Returns true if [raterUid] has submitted at least one rating in [sessionId].
  Future<bool> hasRatedInSession(String sessionId, String raterUid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.ratings(sessionId))
        .where('raterUid', isEqualTo: raterUid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
