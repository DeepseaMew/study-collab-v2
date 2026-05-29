import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/sessions/data/datasources/join_request_datasource.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';

/// Firestore implementation of [JoinRequestRepository].
class JoinRequestRepositoryImpl implements JoinRequestRepository {
  JoinRequestRepositoryImpl(this._datasource, this._sessionDatasource);

  final JoinRequestDatasource _datasource;
  final SessionDatasource _sessionDatasource;

  @override
  Stream<List<JoinRequestEntity>> watchRequests(String sessionId) {
    return _datasource
        .watchRequests(sessionId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<bool> watchMyRequest(String sessionId, String uid) {
    return _datasource.watchMyRequest(sessionId, uid);
  }

  @override
  Future<void> submitRequest(
    String sessionId,
    JoinRequestEntity request,
  ) async {
    final data = <String, dynamic>{
      'uid': request.uid,
      'displayName': request.displayName,
      if (request.photoUrl != null) 'photoUrl': request.photoUrl,
    };
    await _datasource.submitRequest(sessionId, data);
  }

  @override
  Future<void> approveRequest(
    String sessionId,
    String callerUid,
    String requestUid,
  ) async {
    final session = await _sessionDatasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException('Only the host may approve requests.');
    }
    await _datasource.approveRequest(sessionId, requestUid);
  }

  @override
  Future<void> declineRequest(
    String sessionId,
    String callerUid,
    String requestUid,
  ) async {
    final session = await _sessionDatasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException('Only the host may decline requests.');
    }
    await _datasource.declineRequest(sessionId, requestUid);
  }

  @override
  Future<void> withdrawRequest(String sessionId, String uid) async {
    await _datasource.withdrawRequest(sessionId, uid);
  }

  @override
  Future<void> submitRequestWithPin(
    String sessionId,
    JoinRequestEntity request,
    String pin,
  ) async {
    final data = <String, dynamic>{
      'uid': request.uid,
      'displayName': request.displayName,
      if (request.photoUrl != null) 'photoUrl': request.photoUrl,
      'pin': pin,
    };
    await _datasource.submitPinRequest(sessionId, data);
    appLogger.info(
      'PIN-validated join request submitted (pending host approval)',
      extra: {'sessionId': sessionId},
    );
  }

  @override
  Future<void> joinWithPin(
    String sessionId,
    JoinRequestEntity request,
    String pin,
  ) async {
    // Write the request with the PIN field. Firestore rules validate
    // server-side that the PIN matches sessions/{sessionId}.pin.
    // InvalidPinException is thrown by the datasource on permission-denied.
    final data = <String, dynamic>{
      'uid': request.uid,
      'displayName': request.displayName,
      if (request.photoUrl != null) 'photoUrl': request.photoUrl,
      'pin': pin,
    };
    await _datasource.submitPinRequest(sessionId, data);

    // PIN validated. Immediately approve the request to add the joiner.
    await _datasource.approveRequest(sessionId, request.uid);
    appLogger.info(
      'User joined private session with PIN',
      extra: {'sessionId': sessionId},
    );
  }
}
