import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/presentation/providers/session_chat_providers.dart';
import 'package:mobile/features/chat/presentation/widgets/session_message_bubble.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Session (group) chat thread screen.
///
/// Route: `/sessions/:sessionId/chat`
/// Loads the session document to resolve title, memberUids, and hostUid.
/// Fires [AnalyticsEvents.sessionChatOpened] on first frame and
/// [AnalyticsEvents.sessionChatMessageSent] on successful sends.
class SessionChatScreen extends ConsumerStatefulWidget {
  const SessionChatScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _draft = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appLogger.info(AnalyticsEvents.sessionChatOpened);
      _markReadFireAndForget();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markReadFireAndForget() {
    final me = ref.read(firebaseAuthStateProvider).valueOrNull;
    if (me == null) return;
    ref
        .read(sessionChatActionsNotifierProvider.notifier)
        .markSessionRead(widget.sessionId, me.uid);
  }

  Future<void> _send() async {
    final text = _draft.trim();
    if (text.isEmpty) return;

    final me = ref.read(firebaseAuthStateProvider).valueOrNull;
    if (me == null) return;

    final sessionAsync = ref.read(sessionStreamProvider(widget.sessionId));
    final session = sessionAsync.valueOrNull;
    if (session == null) return;

    _inputCtrl.clear();
    setState(() => _draft = '');

    await ref
        .read(sessionChatActionsNotifierProvider.notifier)
        .sendMessage(
          sessionId: widget.sessionId,
          memberUids: session.memberUids,
          senderUid: me.uid,
          senderDisplayName: me.displayName ?? '',
          sessionTitle: session.title,
          text: text,
        );

    final actionsState = ref.read(sessionChatActionsNotifierProvider);
    if (actionsState is AsyncData) {
      appLogger.info(AnalyticsEvents.sessionChatMessageSent);
      _scrollToBottom();
    } else if (actionsState is AsyncError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Interleaves [DateTime] sentinels between messages on different calendar days.
  List<Object> _buildItems(List<SessionMessage> msgs) {
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
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;
    final sessionAsync = ref.watch(sessionStreamProvider(widget.sessionId));
    final messagesAsync = ref.watch(sessionMessagesProvider(widget.sessionId));

    final sessionTitle = sessionAsync.valueOrNull?.title ?? 'Group Chat';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        title: Text(
          sessionTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                appLogger.error(
                  'SessionChatScreen load error',
                  exception: e,
                  stackTrace: st,
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Could not load messages. Please try again.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.hint),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat();
                }
                final items = _buildItems(messages);
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
                    final msg = item as SessionMessage;
                    final isMe = me != null && msg.senderUid == me.uid;
                    if (msg.type == 'file_shared') {
                      return _FileMessageRow(message: msg, isMe: isMe);
                    }
                    return SessionMessageBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputCtrl,
            draft: _draft,
            onChanged: (v) => setState(() => _draft = v),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, size: 48, color: AppColors.disabled),
          const SizedBox(height: 12),
          Text(
            'No messages yet',
            style: tt.bodyMedium?.copyWith(color: AppColors.hint),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to say hello!',
            style: tt.bodyMedium?.copyWith(color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.hint),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

// ── File message row ───────────────────────────────────────────────────────────

class _FileMessageRow extends ConsumerWidget {
  const _FileMessageRow({required this.message, required this.isMe});

  final SessionMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Semantics(
              label:
                  'File: ${message.fileName ?? 'unknown'}. '
                  'Shared by ${isMe ? 'you' : message.senderDisplayName}. '
                  'Tap to open.',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openFile(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.accent : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: isMe ? Colors.white : AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.fileName ?? 'File',
                          style: tt.bodyMedium?.copyWith(
                            color: isMe ? Colors.white : AppColors.text,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    appLogger.info(AnalyticsEvents.sessionChatFileMessageTapped);
    final url = message.downloadUrl;
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File URL is not available.')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open file.')));
      }
    }
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.draft,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final String draft;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = draft.trim().isNotEmpty;
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
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) onSend();
              },
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
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          Semantics(
            label: 'Send message',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.send_rounded),
              color: canSend ? AppColors.accent : AppColors.disabled,
              onPressed: canSend ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}
