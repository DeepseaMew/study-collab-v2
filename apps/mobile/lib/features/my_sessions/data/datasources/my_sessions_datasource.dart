import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';

/// Firestore data source for My Sessions tab queries.
///
/// All path strings come from [FirestorePaths]. Three independent streams
/// serve the three tabs per ADR 0003 sub-decision 1.
class MySessionsDatasource {
  MySessionsDatasource(this._firestore);

  /// Creates a [MySessionsDatasource] wired to the default [FirebaseFirestore]
  /// instance. Use this factory from `@riverpod` repository providers so that
  /// presentation-layer files do not need to import `cloud_firestore` directly.
  factory MySessionsDatasource.withDefaultFirestore() =>
      MySessionsDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(FirestorePaths.sessionsCollection);

  // ── Upcoming — reuses Index 1 (memberUids array-contains, scheduledAt asc)
  /// All sessions the user is a member of, ordered by scheduledAt ascending.
  /// The repository layer applies a client-side `status != 'ended'` filter.
  Stream<List<SessionModel>> watchMemberSessionsForUpcoming(String uid) {
    return _sessions
        .where('memberUids', arrayContains: uid)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  // ── Completed — reuses Index 2 (memberUids, status, endedAt desc)
  /// Sessions the user is a member of that have ended.
  Stream<List<SessionModel>> watchCompletedSessions(String uid) {
    return _sessions
        .where('memberUids', arrayContains: uid)
        .where('status', isEqualTo: 'ended')
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  // ── Hosted — uses Index 9 (hostUid asc, scheduledAt desc)
  /// Sessions hosted by [uid], newest first.
  Stream<List<SessionModel>> watchHostedSessions(String uid) {
    return _sessions
        .where('hostUid', isEqualTo: uid)
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  List<SessionModel> _parseDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            return SessionModel.fromJson(doc.data());
          } catch (e, st) {
            appLogger.error(
              'Failed to parse session document in my_sessions',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<SessionModel>()
        .toList();
  }
}
