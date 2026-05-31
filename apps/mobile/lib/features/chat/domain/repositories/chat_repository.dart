import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';

/// Abstract repository interface for DM chat operations.
///
/// All methods accept and return pure Dart types only — no Firestore types
/// cross this boundary (ADR 0011 constraint).
///
/// No [DocumentSnapshot] cursor crosses this boundary; pagination uses a
/// nullable [DateTime] timestamp cursor instead.
abstract interface class ChatRepository {
  /// Streams the list of DM conversations for [uid], ordered by
  /// `lastMessageAt` descending (Index 11).
  Stream<List<DmConversation>> streamConversations(String uid);

  /// Streams the messages in [dmId], newest last.
  ///
  /// [limit] defaults to 50. [startAfter] is an optional [DateTime] cursor
  /// for pagination (the `sentAt` value of the oldest message already loaded).
  Stream<List<DmMessage>> streamMessages(
    String dmId, {
    int limit = 50,
    DateTime? startAfter,
  });

  /// Sends a message in the DM conversation identified by [dmId].
  ///
  /// Write sequence (ADR 0011 SD3 — two sequential `await` calls):
  ///   1. `messages/{messageId}` set
  ///   2. `dms/{dmId}` update with `lastMessageText`, `lastMessageAt`,
  ///      and `unreadCounts` increment for [recipientUid]
  ///
  /// Verifies the friends gate client-side before any Firestore write.
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  });

  /// Zeroes [uid]'s unread count for [dmId].
  Future<void> markRead(String dmId, String uid);
}
