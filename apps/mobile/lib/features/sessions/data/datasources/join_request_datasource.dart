import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/models/join_request_model.dart';

/// Firestore data source for the `sessions/{sessionId}/requests` subcollection.
///
/// All path strings come from [FirestorePaths].
class JoinRequestDatasource {
  JoinRequestDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _requestsCollection(
    String sessionId,
  ) => _firestore.collection(
    FirestorePaths.sessionRequestsCollection(sessionId),
  );

  DocumentReference<Map<String, dynamic>> _requestDoc(
    String sessionId,
    String uid,
  ) => _firestore.doc(FirestorePaths.sessionRequestDoc(sessionId, uid));

  DocumentReference<Map<String, dynamic>> _sessionDoc(String sessionId) =>
      _firestore.doc(FirestorePaths.sessionDoc(sessionId));

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Watches whether a single requester's own request document exists.
  ///
  /// Reads only `sessions/{sessionId}/requests/{uid}` — never a collection
  /// query. Returns true while the document is present (request is pending).
  Stream<bool> watchMyRequest(String sessionId, String uid) {
    return _requestDoc(sessionId, uid).snapshots().map((doc) => doc.exists);
  }

  /// Watches all join requests for a session.
  Stream<List<JoinRequestModel>> watchRequests(String sessionId) {
    return _requestsCollection(
      sessionId,
    ).orderBy('requestedAt', descending: false).snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            try {
              return JoinRequestModel.fromJson(doc.data());
            } catch (e, st) {
              appLogger.error(
                'Failed to parse join request document',
                exception: e,
                stackTrace: st,
                extra: {'sessionId': sessionId, 'docId': doc.id},
              );
              return null;
            }
          })
          .whereType<JoinRequestModel>()
          .toList();
    });
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Submits a join request.
  Future<void> submitRequest(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    final uid = data['uid'] as String;
    try {
      data['requestedAt'] = FieldValue.serverTimestamp();
      await _requestDoc(sessionId, uid).set(data);
      appLogger.info('Join request submitted', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore submit join request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not submit join request: ${e.message}');
    }
  }

  /// Submits a join request that includes a PIN field for server-side validation.
  ///
  /// Firestore rules verify `request.resource.data.pin == session.pin` before
  /// allowing the write. If the PIN is wrong, Firestore returns
  /// `permission-denied` and this method throws [InvalidPinException].
  Future<void> submitPinRequest(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    final uid = data['uid'] as String;
    try {
      data['requestedAt'] = FieldValue.serverTimestamp();
      await _requestDoc(sessionId, uid).set(data);
      appLogger.info(
        'Pin-validated join request submitted',
        extra: {'sessionId': sessionId},
      );
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        throw const InvalidPinException('Incorrect PIN. Please try again.');
      }
      appLogger.error(
        'Firestore submit pin request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not submit pin request: ${e.message}');
    }
  }

  /// Approves a join request using a WriteBatch.
  ///
  /// Atomically:
  ///   1. Deletes `sessions/{sessionId}/requests/{requestUid}`.
  ///   2. arrayUnion [requestUid] to `sessions/{sessionId}.memberUids`.
  Future<void> approveRequest(String sessionId, String requestUid) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_requestDoc(sessionId, requestUid));
      batch.update(_sessionDoc(sessionId), {
        'memberUids': FieldValue.arrayUnion([requestUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      appLogger.info('Join request approved', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore approve join request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not approve request: ${e.message}');
    }
  }

  /// Declines a join request by deleting its document.
  Future<void> declineRequest(String sessionId, String requestUid) async {
    try {
      await _requestDoc(sessionId, requestUid).delete();
      appLogger.info('Join request declined', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore decline join request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not decline request: ${e.message}');
    }
  }

  /// Allows the requesting user to withdraw their own pending request.
  Future<void> withdrawRequest(String sessionId, String uid) async {
    try {
      await _requestDoc(sessionId, uid).delete();
      appLogger.info('Join request withdrawn', extra: {'sessionId': sessionId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'Firestore withdraw join request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': sessionId, 'code': e.code},
      );
      throw DataException('Could not withdraw request: ${e.message}');
    }
  }
}
