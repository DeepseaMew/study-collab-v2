import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';

/// Firestore data source for the `sessions` collection.
///
/// All path strings come from [FirestorePaths]. No path strings are inlined.
/// Only this file (and the repository impl) may interact with the sessions
/// Firestore collection.
class SessionDatasource {
  SessionDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(FirestorePaths.sessionsCollection);

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) =>
      _firestore.doc(FirestorePaths.sessionDoc(sessionId));

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Watches a single session document.
  Stream<SessionModel?> watchSession(String sessionId) {
    return _sessionRef(sessionId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return SessionModel.fromJson(snap.data()!);
      } catch (e, st) {
        appLogger.error(
          'Failed to parse session document',
          exception: e,
          stackTrace: st,
          extra: {'sessionId': sessionId},
        );
        return null;
      }
    });
  }

  /// Watches all public sessions, ordered by scheduledAt ascending.
  Stream<List<SessionModel>> watchPublicSessions() {
    return _sessions
        .where('visibility', isEqualTo: 'public')
        .orderBy('scheduledAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            try {
              return SessionModel.fromJson(doc.data());
            } catch (e, st) {
              appLogger.error(
                'Failed to parse public session document',
                exception: e,
                stackTrace: st,
              );
              return null;
            }
          }).whereType<SessionModel>().toList(),
        );
  }

  /// Watches sessions where the given UID is a member, ordered by scheduledAt asc.
  /// Uses Index 1 from ADR 0001.
  Stream<List<SessionModel>> watchMemberSessions(String uid) {
    return _sessions
        .where('memberUids', arrayContains: uid)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  /// Watches sessions that have ended and include the given UID as a member.
  /// Uses Index 2 from ADR 0001.
  Stream<List<SessionModel>> watchCompletedSessions(String uid) {
    return _sessions
        .where('memberUids', arrayContains: uid)
        .where('status', isEqualTo: 'ended')
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  /// Watches sessions hosted by [uid], ordered by scheduledAt desc.
  /// Uses Index 9 from ADR 0001 Amendment 1.
  Stream<List<SessionModel>> watchHostedSessions(String uid) {
    return _sessions
        .where('hostUid', isEqualTo: uid)
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((snap) => _parseDocs(snap.docs));
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new session document.
  Future<void> createSession(Map<String, dynamic> data) async {
    try {
      final ref = _sessions.doc();
      final sessionId = ref.id;
      data['sessionId'] = sessionId;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(data);
      appLogger.info('Session created', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore create session failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not create session: ${e.message}');
    }
  }

  /// Creates a new session document with a predetermined ID.
  Future<String> createSessionAndReturnId(Map<String, dynamic> data) async {
    try {
      final ref = _sessions.doc();
      final sessionId = ref.id;
      data['sessionId'] = sessionId;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(data);
      appLogger.info('Session created', extra: {'sessionId': sessionId});
      return sessionId;
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore create session failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not create session: ${e.message}');
    }
  }

  /// Updates mutable fields on an existing session.
  Future<void> updateSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _sessionRef(sessionId).update(updates);
      appLogger.info('Session updated', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore update session failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not update session: ${e.message}');
    }
  }

  /// Deletes a session document.
  Future<void> deleteSession(String sessionId) async {
    try {
      await _sessionRef(sessionId).delete();
      appLogger.info('Session deleted', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore delete session failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not delete session: ${e.message}');
    }
  }

  /// Reads only the `pin` field of a session document.
  ///
  /// Returns `null` when the session has no PIN (public session).
  /// Must only be called after verifying the caller is the host.
  Future<String?> fetchSessionPin(String sessionId) async {
    try {
      final snap = await _sessionRef(sessionId).get();
      return snap.data()?['pin'] as String?;
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore fetch session pin failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not fetch session PIN: ${e.message}');
    }
  }

  /// Reads a user document by UID for host denormalization.
  Future<Map<String, dynamic>?> readUserDoc(String uid) async {
    try {
      final snap = await _firestore.doc(FirestorePaths.userDoc(uid)).get();
      return snap.data();
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore read user failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw DataException('Could not read user data: ${e.message}');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<SessionModel> _parseDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      try {
        return SessionModel.fromJson(doc.data());
      } catch (e, st) {
        appLogger.error(
          'Failed to parse session document',
          exception: e,
          stackTrace: st,
          extra: {'docId': doc.id},
        );
        return null;
      }
    }).whereType<SessionModel>().toList();
  }
}
