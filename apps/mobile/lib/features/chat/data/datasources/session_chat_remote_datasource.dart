import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/chat/data/models/group_chat_summary_model.dart';
import 'package:mobile/features/chat/data/models/session_message_model.dart';

/// Firestore data source for session (group) chat.
///
/// Message send uses [WriteBatch] to atomically write the message document
/// and update every member's `users/{uid}/groupChats/{sessionId}` summary
/// (ADR 0012 SD1). This is safe because the `isMember(sessionId)` rule reads
/// `sessions/{sessionId}` — a document the batch never writes — so there is no
/// rule-evaluation conflict (contrast ADR 0011 SD3).
class SessionChatRemoteDatasource {
  SessionChatRemoteDatasource(this._firestore);

  factory SessionChatRemoteDatasource.withDefaultFirestore() =>
      SessionChatRemoteDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messagesCol(String sessionId) =>
      _firestore.collection(
        FirestorePaths.sessionMessagesCollection(sessionId),
      );

  // ── Streams ───────────────────────────────────────────────────────────────────

  /// Streams messages for [sessionId] ordered by `sentAt` ascending.
  ///
  /// Returns at most [limit] messages. Reflects new messages in real time.
  Stream<List<SessionMessageModel>> streamMessages(
    String sessionId, {
    int limit = 50,
  }) {
    return _messagesCol(sessionId)
        .orderBy('sentAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) => _parseMessageDocs(snap.docs));
  }

  /// Streams the `users/{uid}/groupChats` collection ordered by
  /// `lastMessageAt` descending (Index 12, ADR 0012 SD5).
  Stream<List<GroupChatSummaryModel>> streamGroupChatSummaries(String uid) {
    return _firestore
        .collection(FirestorePaths.userGroupChatsCollection(uid))
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => _parseSummaryDocs(snap.docs));
  }

  // ── Reads ─────────────────────────────────────────────────────────────────────

  /// Fetches older messages before [startAfter] (cursor-based pagination).
  Future<List<SessionMessageModel>> getOlderMessages(
    String sessionId,
    DateTime startAfter, {
    int limit = 50,
  }) async {
    try {
      final snap = await _messagesCol(sessionId)
          .orderBy('sentAt', descending: false)
          .endBefore([Timestamp.fromDate(startAfter)])
          .limitToLast(limit)
          .get();
      return _parseMessageDocs(snap.docs);
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'session_chat: getOlderMessages failed sessionId=$sessionId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      throw ChatDataException('Could not load messages: ${e.message}');
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────────────

  /// Sends a text message to the session chat using a [WriteBatch].
  ///
  /// Batch writes:
  ///   1. The message document at `sessions/{sessionId}/messages/{messageId}`.
  ///   2. For each member: `users/{uid}/groupChats/{sessionId}` with merge:
  ///      - sender gets `unreadCount: 0`
  ///      - all other members get `unreadCount: FieldValue.increment(1)`
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) async {
    final messageRef = _messagesCol(sessionId).doc();
    final messageId = messageRef.id;
    final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;

    final batch = _firestore.batch();

    // Write 1: message document.
    batch.set(messageRef, {
      'messageId': messageId,
      'type': 'text',
      'senderUid': senderUid,
      'senderDisplayName': senderDisplayName,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Write 2..N: groupChats fan-out for every member.
    for (final memberUid in memberUids) {
      final summaryRef = _firestore.doc(
        FirestorePaths.userGroupChatDoc(memberUid, sessionId),
      );
      batch.set(summaryRef, {
        'sessionId': sessionId,
        'sessionTitle': sessionTitle,
        'lastMessageText': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': memberUid == senderUid ? 0 : FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      appLogger.debug(
        'session_chat: message sent sessionId=$sessionId messageId=$messageId',
      );
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'session_chat: sendMessage batch failed sessionId=$sessionId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      throw ChatDataException('Could not send message: ${e.message}');
    }
  }

  /// Zeroes `unreadCount` in `users/{uid}/groupChats/{sessionId}`.
  Future<void> markSessionRead(String sessionId, String uid) async {
    try {
      final ref = _firestore.doc(
        FirestorePaths.userGroupChatDoc(uid, sessionId),
      );
      await ref.update({'unreadCount': 0});
      appLogger.debug('session_chat: markSessionRead sessionId=$sessionId');
    } on FirebaseException catch (e, st) {
      if (e.code == 'not-found') {
        // Summary doc doesn't exist yet — nothing to zero.
        appLogger.debug(
          'session_chat: markSessionRead doc not found, skipping sessionId=$sessionId',
        );
        return;
      }
      appLogger.error(
        'session_chat: markSessionRead failed sessionId=$sessionId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'session_chat_mark_read failed',
        );
      }
      throw ChatDataException('Could not mark session read: ${e.message}');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  /// Converts [Timestamp] fields to epoch milliseconds so that Freezed models
  /// have no dependency on `cloud_firestore`.
  Map<String, dynamic> _convertMessageTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    final sentAt = result['sentAt'];
    if (sentAt is Timestamp) {
      result['sentAt'] = sentAt.millisecondsSinceEpoch;
    }
    return result;
  }

  Map<String, dynamic> _convertSummaryTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    final lastMessageAt = result['lastMessageAt'];
    if (lastMessageAt is Timestamp) {
      result['lastMessageAt'] = lastMessageAt.millisecondsSinceEpoch;
    }
    return result;
  }

  List<SessionMessageModel> _parseMessageDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            return SessionMessageModel.fromJson(
              _convertMessageTimestamps(doc.data()),
            );
          } catch (e, st) {
            appLogger.error(
              'session_chat: failed to parse message document',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<SessionMessageModel>()
        .toList();
  }

  List<GroupChatSummaryModel> _parseSummaryDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            return GroupChatSummaryModel.fromJson(
              _convertSummaryTimestamps(doc.data()),
            );
          } catch (e, st) {
            appLogger.error(
              'session_chat: failed to parse group summary document',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<GroupChatSummaryModel>()
        .toList();
  }
}
