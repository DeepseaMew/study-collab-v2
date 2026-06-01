import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';

/// Params for [CreateNotificationUseCase.execute].
class CreateNotificationParams {
  const CreateNotificationParams({
    required this.recipientUid,
    required this.actorUid,
    required this.actorDisplayName,
    required this.type,
    this.sessionId,
    this.sessionTitle,
  });

  final String recipientUid;
  final String actorUid;
  final String actorDisplayName;
  final NotificationType type;
  final String? sessionId;
  final String? sessionTitle;
}

/// Writes a notification document to the recipient's subcollection (ADR 0013 SD4).
///
/// Always sets `isRead = false` and `actorUid == currentUid`.
/// Fire-and-forget at call sites — failure must not block the primary action.
class CreateNotificationUseCase {
  const CreateNotificationUseCase(this._repository);

  final NotificationRepository _repository;

  Future<void> execute(CreateNotificationParams params) {
    return _repository.createNotification(
      recipientUid: params.recipientUid,
      actorUid: params.actorUid,
      actorDisplayName: params.actorDisplayName,
      type: params.type,
      sessionId: params.sessionId,
      sessionTitle: params.sessionTitle,
    );
  }
}
