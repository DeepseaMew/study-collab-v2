import 'package:mobile/core/logger.dart';
import 'package:mobile/features/chat/data/datasources/session_chat_remote_datasource.dart';
import 'package:mobile/features/chat/data/repositories/session_chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/domain/usecases/mark_session_read.dart';
import 'package:mobile/features/chat/domain/usecases/send_session_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_chat_providers.g.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the [SessionChatRepositoryImpl].
///
/// [keepAlive: true] because the repository is stateless and expensive to
/// recreate; it is shared across screens.
@Riverpod(keepAlive: true)
SessionChatRepositoryImpl sessionChatRepository(SessionChatRepositoryRef ref) {
  return SessionChatRepositoryImpl(
    SessionChatRemoteDatasource.withDefaultFirestore(),
  );
}

// ── Streams ───────────────────────────────────────────────────────────────────

/// Streams messages for [sessionId] ordered by `sentAt` ascending.
@riverpod
Stream<List<SessionMessage>> sessionMessages(
  SessionMessagesRef ref,
  String sessionId,
) {
  return ref.watch(sessionChatRepositoryProvider).streamMessages(sessionId);
}

/// Streams group-chat summaries for [uid] ordered by `lastMessageAt` desc
/// (Index 12, ADR 0012 SD5).
@riverpod
Stream<List<GroupChatSummary>> groupChatSummaries(
  GroupChatSummariesRef ref,
  String uid,
) {
  return ref.watch(sessionChatRepositoryProvider).streamGroupChatSummaries(uid);
}

/// Total unread count across all group chats for [uid].
///
/// Drives the unread badge on the Groups tab chip.
@riverpod
int unreadGroupTotal(UnreadGroupTotalRef ref, String uid) {
  final summaries = ref.watch(groupChatSummariesProvider(uid));
  return summaries.valueOrNull?.fold<int>(0, (sum, s) => sum + s.unreadCount) ??
      0;
}

// ── Actions ───────────────────────────────────────────────────────────────────

/// Notifier wrapping [SendSessionMessage] and [MarkSessionRead].
///
/// State is `AsyncValue<void>` — idle on `AsyncData(null)`, loading while
/// sending.
@riverpod
class SessionChatActionsNotifier extends _$SessionChatActionsNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Sends a text message. State is set to [AsyncError] on failure.
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) async {
    state = const AsyncLoading();
    final useCase = SendSessionMessage(ref.read(sessionChatRepositoryProvider));
    state = await AsyncValue.guard(
      () => useCase.execute(
        sessionId: sessionId,
        memberUids: memberUids,
        senderUid: senderUid,
        senderDisplayName: senderDisplayName,
        sessionTitle: sessionTitle,
        text: text,
      ),
    );
  }

  /// Marks the session chat as read. Fire-and-forget; failures are swallowed.
  Future<void> markSessionRead(String sessionId, String uid) async {
    final useCase = MarkSessionRead(ref.read(sessionChatRepositoryProvider));
    try {
      await useCase.execute(sessionId, uid);
    } catch (_) {
      appLogger.warning(
        'session_chat: markSessionRead swallowed error sessionId=$sessionId',
      );
    }
  }
}
