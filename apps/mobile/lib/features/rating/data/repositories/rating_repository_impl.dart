import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/rating_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/rating/data/datasources/rating_datasource.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';

/// Firestore-backed implementation of [RatingRepository].
class RatingRepositoryImpl implements RatingRepository {
  RatingRepositoryImpl(this._datasource);

  final RatingDatasource _datasource;

  /// Returns the uid of the currently authenticated user, or '' if signed out.
  ///
  /// Fetched fresh on every [submitRatings] call so that a [keepAlive]
  /// repository instance constructed before sign-in completes does not carry
  /// a stale uid. Callers must check for empty string before use (SEC-R03).
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Future<void> submitRatings(String sessionId, List<String> rateeUids) async {
    // SEC-R03: fail fast if auth state is absent rather than letting an
    // empty-string raterUid reach Firestore and produce a misleading
    // permission-denied error.
    final currentUid = _currentUserId;
    if (currentUid.isEmpty) {
      throw const RatingError.submitFailed('unauthenticated');
    }

    try {
      // Bug 3 / Bug 1 guard: check for prior submission before touching
      // Firestore. Without this, a second submitRatings call for the same
      // session attempts to overwrite an existing rating doc. Firestore rules
      // have `allow update: if false` on ratings, so the overwrite fails with
      // permission-denied rather than a meaningful domain error.
      final alreadyRated = await _datasource.hasRatedInSession(
        sessionId,
        currentUid,
      );
      if (alreadyRated) {
        appLogger.warning(
          'rating: submitRatings blocked — already rated in session',
          extra: {'sessionId': sessionId},
        );
        throw const RatingError.alreadyRated();
      }

      for (var i = 0; i < rateeUids.length; i++) {
        final rateeUid = rateeUids[i];
        // SEC-R01: loop index used instead of rateeUid — UIDs are PII.
        appLogger.debug(
          'rating: step 1 — countThumbsUpReceived',
          extra: {'sessionId': sessionId, 'rateeIndex': i},
        );
        final thumbsUp = await _datasource.countThumbsUpReceived(rateeUid);
        appLogger.debug(
          'rating: step 2 — countEndedSessionsJoined',
          extra: {
            'sessionId': sessionId,
            'rateeIndex': i,
            'thumbsUp': thumbsUp,
          },
        );
        // countEndedSessionsJoined is called with rateeUid (not raterUid) so
        // the denominator reflects the number of ended sessions the RATEE has
        // participated in — the correct denominator for their profile score.
        final endedSessions = await _datasource.countEndedSessionsJoined(
          rateeUid,
        );
        final denominator = endedSessions > 0 ? endedSessions : 1;
        // +1 accounts for the rating being written in this iteration.
        // clamp to [0.0, 1.0]: multiple raters in one session can push
        // thumbsUp above endedSessions, producing a raw ratio > 1.0, which
        // violates the spec's "percentage" semantics (Bug 2).
        final newScore = ((thumbsUp + 1) / denominator).clamp(0.0, 1.0);
        appLogger.debug(
          'rating: step 3 — writeRatingBatch',
          extra: {
            'sessionId': sessionId,
            'rateeIndex': i,
            'endedSessions': endedSessions,
            'newScore': newScore,
          },
        );
        await _datasource.writeRatingBatch(
          sessionId,
          currentUid,
          rateeUid,
          newScore,
        );
        appLogger.debug(
          'rating: step 3 complete',
          extra: {'sessionId': sessionId, 'rateeIndex': i},
        );
      }
    } on RatingError {
      // Domain errors thrown inside the try block (e.g., alreadyRated) must
      // propagate unchanged to the caller. They are not Crashlytics-worthy.
      rethrow;
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        throw const RatingError.submitFailed('permission_denied');
      }
      if (e.code == 'unavailable') {
        appLogger.warning(
          'rating: Firestore unavailable — offline not supported',
          extra: {'errorCode': e.code},
        );
        throw const RatingError.offlineNotSupported();
      }
      appLogger.error(
        'rating: unexpected FirebaseException during submitRatings',
        exception: e,
        stackTrace: st,
        extra: {'errorCode': e.code},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    } catch (e, st) {
      // On Web the JS Firebase SDK throws a FirebaseError that does not always
      // become a Dart FirebaseException, so it bypasses the typed catch above.
      // SEC-R02: match on runtimeType name rather than the full message string
      // to avoid false positives from unrelated exceptions whose toString()
      // happens to contain 'permission-denied' or 'unavailable'.
      final typeName = e.runtimeType.toString();
      if (typeName.contains('FirebaseError') || typeName.contains('JsError')) {
        final msg = e.toString();
        if (msg.contains('permission-denied')) {
          throw const RatingError.submitFailed('permission_denied');
        }
        if (msg.contains('unavailable')) {
          appLogger.warning(
            'rating: Firestore unavailable — offline not supported (web path)',
            extra: {'errorType': typeName},
          );
          throw const RatingError.offlineNotSupported();
        }
      }
      appLogger.error(
        'rating: unexpected error during submitRatings',
        exception: e,
        stackTrace: st,
        extra: {'errorType': typeName},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  @override
  Stream<List<RatingEntity>> watchSessionRatings(String sessionId) {
    return _datasource
        .watchSessionRatings(sessionId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<bool> hasRatedInSession(String sessionId, String raterUid) =>
      _datasource.hasRatedInSession(sessionId, raterUid);
}
