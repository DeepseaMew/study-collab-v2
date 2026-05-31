import 'package:flutter/material.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Renders a single text message bubble in a session (group) chat thread.
///
/// Own messages (isMe = true): right-aligned, accent (#894DEF) background,
/// white text.
/// Others: left-aligned, secondary (#EDE9FE) background, text (#1A1A2E),
/// sender name shown above the bubble.
///
/// `Semantics` label describes the message for accessibility.
class SessionMessageBubble extends StatelessWidget {
  const SessionMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final SessionMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final timeStr = _formatTime(message.sentAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Semantics(
              label:
                  '${isMe ? 'You' : message.senderDisplayName}: ${message.text ?? ''}, sent at $timeStr',
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderDisplayName,
                        style: tt.labelSmall?.copyWith(
                          color: AppColors.hint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                      message.text ?? '',
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
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }
}
