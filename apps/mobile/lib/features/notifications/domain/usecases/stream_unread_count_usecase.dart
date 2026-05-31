import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';

/// Streams the count of unread notifications for the current user (ADR 0013 SD2).
class StreamUnreadCountUseCase {
  const StreamUnreadCountUseCase(this._repository);

  final NotificationRepository _repository;

  Stream<int> execute(String recipientUid) {
    return _repository.streamUnreadCount(recipientUid);
  }
}
