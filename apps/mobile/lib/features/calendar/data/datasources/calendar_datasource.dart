import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';

/// Firestore datasource for calendar session queries.
class CalendarDatasource {
  CalendarDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Streams sessions where [uid] is listed in `memberUids` and
  /// `scheduledAt` falls within [[start], [end]] (inclusive).
  Stream<List<SessionModel>> watchSessionsInRange(
    String uid,
    DateTime start,
    DateTime end,
  ) {
    appLogger.debug(
      'calendar: querying sessions windowStart=$start windowEnd=$end',
    );
    return _firestore
        .collection(FirestorePaths.sessionsCollection)
        .where('memberUids', arrayContains: uid)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('scheduledAt')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => SessionModel.fromJson(d.data())).toList(),
        );
  }
}
