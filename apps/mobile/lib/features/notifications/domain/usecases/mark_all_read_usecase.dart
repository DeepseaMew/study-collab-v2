import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';

/// Batch-marks all unread notifications as read on panel open (ADR 0013 SD5).
class MarkAllReadUseCase {
  const MarkAllReadUseCase(this._repository);

  final NotificationRepository _repository;

  Future<void> execute(String recipientUid) {
    return _repository.markAllRead(recipientUid);
  }
}
