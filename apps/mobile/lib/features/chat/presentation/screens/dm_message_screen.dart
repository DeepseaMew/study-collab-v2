import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_message_bubble.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// DM thread screen.
///
/// Route: `/messages/dm/:id`
/// [dmId] is the Firestore document ID.
/// [otherUid] and [displayName] are passed via GoRouter `extra`.
class DmMessageScreen extends ConsumerStatefulWidget {
  const DmMessageScreen({
    super.key,
    required this.dmId,
    required this.otherUid,
    required this.displayName,
  });

  final String dmId;
  final String otherUid;
  final String displayName;

  @override
  ConsumerState<DmMessageScreen> createState() => _DmMessageScreenState();
}

class _DmMessageScreenState extends ConsumerState<DmMessageScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      _jumpToBottom();
      appLogger.info(AnalyticsEvents.dmConversationOpened);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final me = ref.read(firebaseAuthStateProvider).valueOrNull;
    if (me == null) return;
    await ref
        .read(chatActionsProvider.notifier)
        .markRead(widget.dmId, me.uid);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final me = ref.read(firebaseAuthStateProvider).valueOrNull;
    if (me == null) return;

    _inputCtrl.clear();

    await ref.read(chatActionsProvider.notifier).sendMessage(
      dmId: widget.dmId,
      senderUid: me.uid,
      senderDisplayName: me.displayName ?? '',
      recipientUid: widget.otherUid,
      text: text,
    );

    final state = ref.read(chatActionsProvider);
    if (state.hasError && mounted) {
      final err = state.error;
      final msg = err is NotFriendsException
          ? err.message
          : 'Failed to send message. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
      appLogger.error(
        'DmMessageScreen send failed',
        exception: err,
        stackTrace: state.stackTrace,
      );
    } else {
      appLogger.info(AnalyticsEvents.dmMessageSent);
      _jumpToBottom();
    }
  }

  /// Interleaves [DateTime] date-separator sentinels between messages on
  /// different calendar days.
  List<Object> _buildItems(List<DmMessage> msgs) {
    final items = <Object>[];
    DateTime? lastDate;
    for (final m in msgs) {
      final d = DateUtils.dateOnly(m.sentAt);
      if (lastDate == null || d != lastDate) {
        items.add(d);
        lastDate = d;
      }
      items.add(m);
    }
    return items;
  }

  String _dateLabel(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;
    final messagesAsync = ref.watch(dmMessagesProvider(widget.dmId));

    // Auto-scroll when new messages arrive.
    ref.listen(dmMessagesProvider(widget.dmId), (_, next) {
      if (next.hasValue) _jumpToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: _AppBarTitle(
          displayName: widget.displayName,
          otherUid: widget.otherUid,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                appLogger.error(
                  'DmMessageScreen messages load error',
                  exception: e,
                  stackTrace: st,
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Could not load messages. Please try again.',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.hint,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
              data: (msgs) {
                if (msgs.isEmpty) {
                  return _EmptyDm(label: widget.displayName);
                }
                final items = _buildItems(msgs);
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    if (item is DateTime) {
                      return _DateSeparator(label: _dateLabel(item));
                    }
                    final msg = item as DmMessage;
                    final isMe = me?.uid == msg.senderUid;
                    return DmMessageBubble(
                      message: msg,
                      isMe: isMe,
                      onAvatarTap: isMe
                          ? null
                          : () => context.push('/profile/${msg.senderUid}'),
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(controller: _inputCtrl, onSend: _send),
        ],
      ),
    );
  }
}

// ── AppBar title ──────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.displayName, required this.otherUid});

  final String displayName;
  final String otherUid;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final label = displayName.isEmpty ? 'Unknown User' : displayName;
    final initial = label[0].toUpperCase();

    return Semantics(
      label: 'View $label profile',
      button: true,
      child: GestureDetector(
        onTap: otherUid.isNotEmpty
            ? () => context.push('/profile/$otherUid')
            : null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (otherUid.isNotEmpty)
                    Text(
                      'Tap to view profile',
                      style: tt.labelSmall?.copyWith(color: AppColors.hint),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDm extends StatelessWidget {
  const _EmptyDm({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final name = label.isEmpty ? 'your friend' : label;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.waving_hand_outlined,
            size: 48,
            color: AppColors.disabled,
          ),
          const SizedBox(height: 12),
          Text(
            'Say hi to $name!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.hint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.hint,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLength: 4000,
              buildCounter:
                  (
                    _,
                    {required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send message',
            icon: const Icon(Icons.send_rounded),
            color: AppColors.accent,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
