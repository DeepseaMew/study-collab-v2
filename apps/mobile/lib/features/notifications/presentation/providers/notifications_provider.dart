import 'package:mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_provider.g.dart';

/// Provides the [NotificationRepository] implementation.
///
/// [NotificationRemoteDatasource.withDefaultFirestore] is called here so no
/// `cloud_firestore` import is needed in presentation-layer files.
@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepositoryImpl(
    NotificationRemoteDatasource.withDefaultFirestore(),
  );
}

/// Streams the latest 50 notifications for [recipientUid].
@riverpod
Stream<List<NotificationEntity>> notifications(
  NotificationsRef ref,
  String recipientUid,
) {
  return ref
      .watch(notificationRepositoryProvider)
      .streamNotifications(recipientUid);
}

/// Streams the unread notification count for [recipientUid].
@riverpod
Stream<int> unreadNotificationCount(
  UnreadNotificationCountRef ref,
  String recipientUid,
) {
  return ref
      .watch(notificationRepositoryProvider)
      .streamUnreadCount(recipientUid);
}
