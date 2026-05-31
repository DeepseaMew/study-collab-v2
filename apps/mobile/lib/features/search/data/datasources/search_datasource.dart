import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';

/// Firestore datasource for the search feature (ADR 0010).
///
/// Query branching strategy (Sub-decision 2):
/// - When [filter.hashtag] is non-null: uses Index 3
///   (`hashtags arrayContains` + optional `academicLevel` + optional `studentYear`).
/// - Otherwise: queries `status == 'scheduled'` and
///   `scheduledAt >= DateTime.now().toUtc()` ordered by `scheduledAt asc`.
///
/// Always adds `visibility == 'public'` to every query so the client never
/// requests documents it cannot read (Firestore rules deny non-member reads
/// on private sessions).
class SearchDatasource {
  SearchDatasource(this._firestore);

  SearchDatasource.withDefaultFirestore()
      : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Executes a Firestore query for [filter] and returns raw [SessionModel] list.
  ///
  /// Never throws [SearchError] directly — lets Firestore exceptions propagate
  /// to [SearchRepositoryImpl] for mapping.
  Future<List<SessionModel>> searchSessions(SearchFilter filter) async {
    appLogger.debug('SearchDatasource.searchSessions', extra: {
      'hasHashtag': filter.hashtag != null,
      'hasAcademicLevel': filter.academicLevel != null,
      'hasStudentYear': filter.studentYear != null,
    });

    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.sessionsCollection)
        .where('visibility', isEqualTo: 'public');

    if (filter.hashtag != null) {
      // Index 3: hashtags arrayContains + optional academicLevel + studentYear.
      query = query.where('hashtags', arrayContains: filter.hashtag);

      if (filter.academicLevel != null) {
        query = query.where('academicLevel', isEqualTo: filter.academicLevel);
      }
      if (filter.studentYear != null) {
        query = query.where('studentYear', isEqualTo: filter.studentYear);
      }
    } else {
      // No hashtag active — query all public sessions using only the
      // auto-created single-field index on 'visibility'.
      // status == 'scheduled' and scheduledAt >= now are applied client-side
      // in SearchRepositoryImpl._matchesFilter to avoid needing a composite
      // index that is not in ADR 0001.
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Server unreachable — serve from Firestore's local cache so the user
        // can still search previously fetched sessions without a connection.
        appLogger.warning(
          'SearchDatasource: server unavailable, falling back to cache',
        );
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } on FirebaseException {
          // No cached data for this query — return empty rather than crashing.
          appLogger.warning('SearchDatasource: cache empty, returning []');
          return [];
        }
      } else {
        rethrow;
      }
    }

    appLogger.debug(
      'SearchDatasource result count',
      extra: {'count': snapshot.docs.length},
    );

    return snapshot.docs
        .map((doc) => SessionModel.fromFirestore(doc.data()))
        .toList();
  }
}
