import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Firestore implementation of [ChatRepository].
///
/// Enforces the client-side friends gate before any Firestore write
/// (ADR 0011: `areFriends()` cannot be called in Firestore rules on the DM
/// path due to the 10-call budget constraint).
final class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._datasource);

  final ChatRemoteDatasource _datasource;

  @override
  Stream<List<DmConversation>> streamConversations(String uid) {
    return _datasource
        .streamConversations(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<List<DmMessage>> streamMessages(
    String dmId, {
    int limit = 50,
    DateTime? startAfter,
  }) {
    return _datasource
        .streamMessages(dmId, limit: limit, startAfter: startAfter)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) async {
    // Client-side friends gate (ADR 0011 constraint).
    final friends = await _datasource.areFriends(senderUid, recipientUid);
    if (!friends) {
      appLogger.warning(
        'sendMessage blocked: users are not friends',
        extra: {},
      );
      throw const NotFriendsException();
    }

    // Ensure the DM doc exists before writing the message subcollection.
    // The message create rule does get(dms/dmId) — the doc must exist first.
    await _datasource.createDm(dmId, senderUid, recipientUid);

    return _datasource.sendMessage(
      dmId: dmId,
      senderUid: senderUid,
      senderDisplayName: senderDisplayName,
      recipientUid: recipientUid,
      text: text,
    );
  }

  @override
  Future<void> markRead(String dmId, String uid) =>
      _datasource.markRead(dmId, uid);
}
