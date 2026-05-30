import 'package:mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/mark_dm_read.dart';
import 'package:mobile/features/chat/domain/usecases/send_dm_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.g.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

/// Provides the [ChatRepository] implementation.
///
/// [ChatRemoteDatasource.withDefaultFirestore] is called here so that no
/// `cloud_firestore` import is needed in this file.
@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return ChatRepositoryImpl(ChatRemoteDatasource.withDefaultFirestore());
}

// ── Streams ────────────────────────────────────────────────────────────────────

/// Streams DM conversations for [uid], ordered by `lastMessageAt` desc
/// (Index 11, ADR 0011).
@riverpod
Stream<List<DmConversation>> dmConversations(
  DmConversationsRef ref,
  String uid,
) {
  return ref.watch(chatRepositoryProvider).streamConversations(uid);
}

/// Streams messages for [dmId], oldest first, limited to 50 per page.
@riverpod
Stream<List<DmMessage>> dmMessages(DmMessagesRef ref, String dmId) {
  return ref.watch(chatRepositoryProvider).streamMessages(dmId);
}

// ── Actions ────────────────────────────────────────────────────────────────────

/// Notifier that wraps [SendDmMessageUseCase] and [MarkDmReadUseCase].
///
/// State is `AsyncValue<void>` — null on idle, loading while sending.
@riverpod
class ChatActions extends _$ChatActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Sends a DM message. On error the state carries the exception.
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) async {
    state = const AsyncLoading();
    final useCase = SendDmMessageUseCase(ref.read(chatRepositoryProvider));
    state = await AsyncValue.guard(
      () => useCase.execute(
        dmId: dmId,
        senderUid: senderUid,
        senderDisplayName: senderDisplayName,
        recipientUid: recipientUid,
        text: text,
      ),
    );
  }

  /// Marks a conversation read (fire-and-forget; silently ignores failures).
  Future<void> markRead(String dmId, String uid) async {
    final useCase = MarkDmReadUseCase(ref.read(chatRepositoryProvider));
    try {
      await useCase.execute(dmId, uid);
    } catch (_) {
      // Intentionally swallowed — stale badge heals on next open (ADR 0011).
    }
  }
}
