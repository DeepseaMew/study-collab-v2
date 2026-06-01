import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_entity.freezed.dart';

/// Notification type enum matching the Firestore `type` field values (ADR 0013).
///
/// Pure Dart — no Flutter or Firebase imports.
enum NotificationType {
  friendRequest,
  friendAccepted,
  joinRequest,
  joinApproved,
  joinDeclined,
  ratingAvailable;

  /// Converts a Firestore string value to [NotificationType].
  static NotificationType fromString(String value) {
    return switch (value) {
      'friend_request' => NotificationType.friendRequest,
      'friend_accepted' => NotificationType.friendAccepted,
      'join_request' => NotificationType.joinRequest,
      'join_approved' => NotificationType.joinApproved,
      'join_declined' => NotificationType.joinDeclined,
      'rating_available' => NotificationType.ratingAvailable,
      _ => throw ArgumentError('Unknown notification type: $value'),
    };
  }

  /// Converts to the Firestore string value.
  String toFirestoreString() {
    return switch (this) {
      NotificationType.friendRequest => 'friend_request',
      NotificationType.friendAccepted => 'friend_accepted',
      NotificationType.joinRequest => 'join_request',
      NotificationType.joinApproved => 'join_approved',
      NotificationType.joinDeclined => 'join_declined',
      NotificationType.ratingAvailable => 'rating_available',
    };
  }
}

/// Domain entity for a user notification (ADR 0013).
///
/// Pure Dart — no Flutter or Firebase imports.
/// All 8 fields from the ADR 0013 Firestore schema are present.
@freezed
abstract class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity({
    required String notifId,
    required NotificationType type,
    required String actorUid,
    required String actorDisplayName,
    String? sessionId,
    String? sessionTitle,
    required bool isRead,
    required DateTime createdAt,
  }) = _NotificationEntity;
}
