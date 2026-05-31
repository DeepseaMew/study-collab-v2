import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';

/// Abstract repository interface for notification operations (ADR 0013).
///
/// All methods accept and return plain Dart types — no Firestore types cross
/// this boundary. Implementations live in `data/repositories/`.
abstract interface class NotificationRepository {
  // ── Streams ──────────────────────────────────────────────────────────────

  /// Streams the latest 50 notifications for [recipientUid] ordered by
  /// `createdAt` descending (ADR 0013 SD3).
  Stream<List<NotificationEntity>> streamNotifications(String recipientUid);

  /// Streams the count of unread notifications for [recipientUid] (ADR 0013 SD2).
  ///
  /// Uses Index 13: `isRead ASC, createdAt DESC`.
  Stream<int> streamUnreadCount(String recipientUid);

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Batch-marks all unread notifications for [recipientUid] as read
  /// (ADR 0013 SD5).
  Future<void> markAllRead(String recipientUid);

  /// Writes a notification document to `users/{recipientUid}/notifications/`
  /// (ADR 0013 SD4).
  ///
  /// [actorUid] is the UID of the user who triggered the event (the caller).
  /// [actorDisplayName] is denormalized at write time and must be non-empty.
  /// [type] is the notification type.
  /// [sessionId] and [sessionTitle] are optional; null for friend-type events.
  Future<void> createNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    required NotificationType type,
    String? sessionId,
    String? sessionTitle,
  });
}
