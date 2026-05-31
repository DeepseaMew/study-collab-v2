import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/usecases/create_notification_usecase.dart';
import 'package:mobile/features/sessions/data/datasources/join_request_datasource.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';

/// Firestore implementation of [JoinRequestRepository].
///
/// Notification triggers 3 (join_request), 4 (join_approved), and
/// 5 (join_declined) are fire-and-forget (ADR 0013). Failure must never block
/// the primary join-request action.
class JoinRequestRepositoryImpl implements JoinRequestRepository {
  JoinRequestRepositoryImpl(this._datasource, this._sessionDatasource)
    : _notifDatasource = NotificationRemoteDatasource.withDefaultFirestore();

  @visibleForTesting
  JoinRequestRepositoryImpl.withNotificationDatasource(
    JoinRequestDatasource datasource,
    SessionDatasource sessionDatasource,
    NotificationRemoteDatasource notificationDatasource,
  ) : _datasource = datasource,
      _sessionDatasource = sessionDatasource,
      _notifDatasource = notificationDatasource;

  final JoinRequestDatasource _datasource;
  final SessionDatasource _sessionDatasource;
  final NotificationRemoteDatasource _notifDatasource;

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

    // Trigger 3: fire-and-forget join_request notification to the host (ADR 0013).
    // Session doc is read inside the closure — non-blocking (R2 resolution).
    _fireJoinRequestNotification(
      sessionId: sessionId,
      actorUid: request.uid,
      actorDisplayName: request.displayName,
    );
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

    // Trigger 4: fire-and-forget join_approved notification to the requester.
    _fireNotification(
      CreateNotificationParams(
        recipientUid: requestUid,
        actorUid: callerUid,
        actorDisplayName: session.hostDisplayName.isNotEmpty
            ? session.hostDisplayName
            : 'The host',
        type: NotificationType.joinApproved,
        sessionId: sessionId,
        sessionTitle: session.title,
      ),
    );
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

    // Trigger 5: fire-and-forget join_declined notification to the requester.
    _fireNotification(
      CreateNotificationParams(
        recipientUid: requestUid,
        actorUid: callerUid,
        actorDisplayName: session.hostDisplayName.isNotEmpty
            ? session.hostDisplayName
            : 'The host',
        type: NotificationType.joinDeclined,
        sessionId: sessionId,
        sessionTitle: session.title,
      ),
    );
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

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fire-and-forget notification write. Failure is logged but never re-thrown
  /// so the primary join-request action is never blocked (ADR 0013).
  void _fireNotification(CreateNotificationParams params) {
    _notifDatasource
        .createNotification(
          recipientUid: params.recipientUid,
          actorUid: params.actorUid,
          actorDisplayName: params.actorDisplayName,
          type: params.type,
          sessionId: params.sessionId,
          sessionTitle: params.sessionTitle,
        )
        .catchError((Object e, StackTrace st) {
          appLogger.error(
            'JoinRequestRepositoryImpl: notification trigger failed (fire-and-forget)',
            exception: e,
            stackTrace: st,
            extra: {'type': params.type.toFirestoreString()},
          );
        });
  }

  /// Fire-and-forget trigger 3: reads session doc to get host UID and title,
  /// then writes a `join_request` notification to the host (R2 resolution).
  void _fireJoinRequestNotification({
    required String sessionId,
    required String actorUid,
    required String actorDisplayName,
  }) {
    Future(() async {
      try {
        final session = await _sessionDatasource.watchSession(sessionId).first;
        if (session == null) {
          appLogger.warning(
            'JoinRequestRepositoryImpl: session not found for join_request notification',
            extra: {'sessionId': sessionId},
          );
          return;
        }
        await _notifDatasource.createNotification(
          recipientUid: session.hostUid,
          actorUid: actorUid,
          actorDisplayName: actorDisplayName.isNotEmpty
              ? actorDisplayName
              : 'A user',
          type: NotificationType.joinRequest,
          sessionId: sessionId,
          sessionTitle: session.title,
        );
      } catch (e, st) {
        appLogger.error(
          'JoinRequestRepositoryImpl: join_request notification trigger failed',
          exception: e,
          stackTrace: st,
        );
      }
    });
  }
}
