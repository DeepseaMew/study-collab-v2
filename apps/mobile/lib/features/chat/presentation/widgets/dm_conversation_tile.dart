import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_unread_badge.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// List tile for a single DM conversation.
///
/// [myUid] is used to determine the other participant and unread count.
/// [displayName] is the resolved name for the other participant; pass the
/// `friendDisplayName` from the friends list or an empty string for fallback.
/// [onTap] is called when the tile is tapped.
class DmConversationTile extends StatelessWidget {
  const DmConversationTile({
    super.key,
    required this.conversation,
    required this.myUid,
    required this.displayName,
    required this.onTap,
  });

  final DmConversation conversation;
  final String myUid;

  /// Resolved display name for the other participant.
  /// Falls back to 'Unknown User' when empty.
  final String displayName;

  final VoidCallback onTap;

  // ── Time label ─────────────────────────────────────────────────────────────

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);

    if (msgDay == today) return DateFormat('h:mm a').format(dt);
    if (msgDay == yesterday) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final unread = conversation.unreadCountForUid(myUid);
    final hasUnread = unread > 0;
    final label = displayName.isEmpty ? 'Unknown User' : displayName;
    final initial = label[0].toUpperCase();

    return ListTile(
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
            Positioned(right: -3, top: -3, child: DmUnreadBadge(count: unread)),
        ],
      ),
      title: Text(
        label,
        style: tt.labelLarge?.copyWith(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        conversation.lastMessageText ?? '',
        style: tt.bodyMedium?.copyWith(
          color: hasUnread ? AppColors.text : AppColors.hint,
          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.lastMessageAt != null
          ? Text(
              _timeLabel(conversation.lastMessageAt!),
              style: tt.labelSmall?.copyWith(color: AppColors.hint),
            )
          : null,
    );
  }
}
