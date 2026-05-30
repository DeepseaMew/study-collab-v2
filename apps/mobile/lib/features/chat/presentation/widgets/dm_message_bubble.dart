import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Chat bubble for a single DM message.
///
/// [isMe] determines alignment and color (accent for sent, secondary for
/// received). Tapping the avatar navigates to the sender's profile.
class DmMessageBubble extends StatelessWidget {
  const DmMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onAvatarTap,
  });

  final DmMessage message;
  final bool isMe;

  /// Called when the sender avatar is tapped. Pass `null` to disable.
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final initial = message.senderDisplayName.isNotEmpty
        ? message.senderDisplayName[0].toUpperCase()
        : '?';
    final senderLabel = message.senderDisplayName.isNotEmpty
        ? message.senderDisplayName
        : 'Unknown User';
    final timeStr = DateFormat('h:mm a').format(message.sentAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Semantics(
              label: 'View $senderLabel profile',
              button: true,
              child: GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.accent : AppColors.secondary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: tt.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    timeStr,
                    style: tt.labelSmall?.copyWith(color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
