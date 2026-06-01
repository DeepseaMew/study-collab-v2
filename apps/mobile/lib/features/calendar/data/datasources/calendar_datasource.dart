import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';

/// Firestore datasource for calendar session queries.
class CalendarDatasource {
  CalendarDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Streams sessions where [uid] is a member (`memberUids`) or the host
  /// (`hostUid`), and `scheduledAt` falls within [[start], [end]] (inclusive).
  ///
  /// Uses [Filter.or] so host-created sessions that predate the memberUids
  /// seed are still returned.
  ///
  /// Uses [SessionModel.fromFirestore] (not [SessionModel.fromJson]) because
  /// Firestore document fields arrive as [Timestamp] objects, not ISO-8601
  /// strings. The generated [fromJson] calls [DateTime.parse] on the raw
  /// field value, which throws a [TypeError] on a [Timestamp] and causes the
  /// stream to silently error — resulting in an empty calendar.
  Stream<List<SessionModel>> watchSessionsInRange(
    String uid,
    DateTime start,
    DateTime end,
  ) {
    appLogger.debug(
      'calendar: querying sessions windowStart=$start windowEnd=$end',
    );
    final startTs = Timestamp.fromDate(start.toUtc());
    final endTs = Timestamp.fromDate(end.toUtc());
    return _firestore
        .collection(FirestorePaths.sessionsCollection)
        .where(
          Filter.or(
            Filter('memberUids', arrayContains: uid),
            Filter('hostUid', isEqualTo: uid),
          ),
        )
        .where('scheduledAt', isGreaterThanOrEqualTo: startTs)
        .where('scheduledAt', isLessThanOrEqualTo: endTs)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) {
          final models = <SessionModel>[];
          for (final doc in snap.docs) {
            try {
              models.add(SessionModel.fromFirestore(doc.data()));
            } catch (e, st) {
              appLogger.error(
                'calendar: failed to deserialize session doc=${doc.id}',
                extra: {'error': e.toString()},
              );
              // Record non-fatal so Crashlytics sees deserialization failures.
              // Skipping the bad document so the rest of the list still renders.
              appLogger.error(
                'calendar: stacktrace for doc=${doc.id}',
                extra: {'stacktrace': st.toString()},
              );
            }
          }
          return models;
        });
  }
}
