import 'package:flutter/material.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A list tile representing a single group-chat entry on the Groups tab.
///
/// Shows: session title, last message preview (or "No messages yet"),
/// time-ago label, and an unread badge when [summary.unreadCount] > 0.
/// Tappable; fires [onTap] on selection.
class GroupChatSummaryTile extends StatelessWidget {
  const GroupChatSummaryTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final GroupChatSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final hasUnread = summary.unreadCount > 0;
    final timeAgo = summary.lastMessageAt != null
        ? _timeAgo(summary.lastMessageAt!)
        : '';
    final initial = summary.sessionTitle.isNotEmpty
        ? summary.sessionTitle[0].toUpperCase()
        : 'G';

    return Semantics(
      label:
          'Group chat: ${summary.sessionTitle}. '
          '${summary.lastMessageText ?? 'No messages yet'}. '
          '${hasUnread ? '${summary.unreadCount} unread.' : ''}',
      button: true,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.secondary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${summary.unreadCount > 99 ? '99+' : summary.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                summary.sessionTitle,
                style: tt.labelLarge?.copyWith(
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeAgo.isNotEmpty)
              Text(
                timeAgo,
                style: tt.labelSmall?.copyWith(
                  color: hasUnread ? AppColors.accent : AppColors.hint,
                ),
              ),
          ],
        ),
        subtitle: Text(
          summary.lastMessageText ?? 'No messages yet',
          style: tt.bodyMedium?.copyWith(
            color: hasUnread ? AppColors.text : AppColors.hint,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
