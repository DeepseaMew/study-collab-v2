import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';

/// Streams the latest 50 notifications for the current user (ADR 0013 SD3).
class StreamNotificationsUseCase {
  const StreamNotificationsUseCase(this._repository);

  final NotificationRepository _repository;

  Stream<List<NotificationEntity>> execute(String recipientUid) {
    return _repository.streamNotifications(recipientUid);
  }
}
