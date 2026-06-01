import 'package:flutter/material.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A list tile displaying a single [NotificationEntity].
///
/// Shows a colored initial avatar derived from [actorDisplayName], a
/// type-derived title, relative time, and an unread tint when [isRead] is
/// false. No PII is logged inside this widget.
class NotificationListTile extends StatelessWidget {
  const NotificationListTile({super.key, required this.notification});

  final NotificationEntity notification;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isUnread = !notification.isRead;

    return Semantics(
      label:
          '${_titleFor(notification)}, ${_relativeTime(notification.createdAt)}${isUnread ? ', unread' : ''}',
      child: Container(
        color: isUnread
            ? AppColors.secondary.withValues(alpha: 0.45)
            : Colors.transparent,
        child: ListTile(
          leading: ExcludeSemantics(
            child: _InitialAvatar(displayName: notification.actorDisplayName),
          ),
          title: Text(
            _titleFor(notification),
            style: tt.bodyMedium?.copyWith(
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            _relativeTime(notification.createdAt),
            style: tt.bodySmall?.copyWith(color: AppColors.hint),
          ),
          trailing: isUnread
              ? const SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  String _titleFor(NotificationEntity n) {
    final actor = n.actorDisplayName;
    return switch (n.type) {
      NotificationType.friendRequest => '$actor sent you a friend request',
      NotificationType.friendAccepted => '$actor accepted your friend request',
      NotificationType.joinRequest =>
        '$actor requested to join ${n.sessionTitle ?? "your session"}',
      NotificationType.joinApproved =>
        'Your request to join ${n.sessionTitle ?? "a session"} was approved',
      NotificationType.joinDeclined =>
        'Your request to join ${n.sessionTitle ?? "a session"} was declined',
      NotificationType.ratingAvailable =>
        '${n.sessionTitle ?? "A session"} has ended — rate your peers',
    };
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
