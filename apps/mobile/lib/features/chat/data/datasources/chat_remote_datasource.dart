import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/chat/data/models/dm_conversation_model.dart';
import 'package:mobile/features/chat/data/models/dm_message_model.dart';

/// Firestore data source for DM chat (`dms/{dmId}` and subcollections).
///
/// [dmId] construction lives HERE only — never in presentation or domain
/// (ADR 0011 constraint): `min(uidA, uidB)_max(uidA, uidB)`.
///
/// Send sequence uses two sequential [await] calls — NOT a [WriteBatch] —
/// because [WriteBatch] silently fails on web when combining a subcollection
/// set with a parent document update (ADR 0011 SD3).
class ChatRemoteDatasource {
  ChatRemoteDatasource(this._firestore);

  factory ChatRemoteDatasource.withDefaultFirestore() =>
      ChatRemoteDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  // ── dmId construction ──────────────────────────────────────────────────────

  /// Constructs the deterministic DM document ID from two participant UIDs.
  ///
  /// `dmId = min(uidA, uidB) + '_' + max(uidA, uidB)` (ADR 0001 / ADR 0011).
  /// Called only from this datasource.
  static String buildDmId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _dmsCol =>
      _firestore.collection(FirestorePaths.dmsCollection);

  DocumentReference<Map<String, dynamic>> _dmDoc(String dmId) =>
      _firestore.doc(FirestorePaths.dmDoc(dmId));

  CollectionReference<Map<String, dynamic>> _messagesCol(String dmId) =>
      _firestore.collection(FirestorePaths.dmMessagesCollection(dmId));

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Streams conversations for [uid], ordered by `lastMessageAt` desc
  /// (Index 11 from ADR 0011).
  Stream<List<DmConversationModel>> streamConversations(String uid) {
    return _dmsCol
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => _parseDmDocs(snap.docs));
  }

  /// Streams messages in [dmId], oldest first, limited to [limit].
  ///
  /// When [startAfter] is provided the query pages forward from that timestamp
  /// cursor.
  Stream<List<DmMessageModel>> streamMessages(
    String dmId, {
    int limit = 50,
    DateTime? startAfter,
  }) {
    Query<Map<String, dynamic>> q = _messagesCol(dmId)
        .orderBy('sentAt', descending: false)
        .limit(limit);

    if (startAfter != null) {
      q = q.startAfter([Timestamp.fromDate(startAfter)]);
    }

    return q.snapshots().map((snap) => _parseMessageDocs(snap.docs));
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Idempotently creates the `dms/{dmId}` document (ADR 0011 SD1).
  ///
  /// Uses `SetOptions(merge: true)` so the call is safe on the first open
  /// (doc doesn't exist → hits `allow create`). When the doc already exists
  /// this call becomes an update; the `allow update` rule blocks fields like
  /// `participantUids` and `createdAt`, so we catch `permission-denied` and
  /// treat it as a no-op (the doc is already in place).
  Future<void> createDm(String dmId, String uidA, String uidB) async {
    final sorted = [uidA, uidB]..sort();
    try {
      await _dmDoc(dmId).set(
        {
          'participantUids': sorted,
          'createdAt': FieldValue.serverTimestamp(),
          'unreadCounts': {uidA: 0, uidB: 0},
          'lastMessageText': null,
          'lastMessageAt': null,
        },
        SetOptions(merge: true),
      );
      appLogger.debug('DM doc created/verified', extra: {'dmId': dmId});
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        // Doc already exists; update rule blocked the re-write. Safe to ignore.
        appLogger.debug(
          'createDm: doc exists, skipping re-create',
          extra: {'dmId': dmId},
        );
        return;
      }
      appLogger.error(
        'ChatRemoteDatasource.createDm failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      throw ChatDataException('Could not create conversation: ${e.message}');
    }
  }

  /// Sends a DM message.
  ///
  /// Caller (`ChatRepositoryImpl`) must call [createDm] before this so the
  /// parent doc is guaranteed to exist.
  ///
  /// Write sequence (ADR 0011 SD3 — two sequential `await` calls):
  ///   1. `messages/{messageId}` set
  ///   2. `dms/{dmId}` update — only the three fields the `allow update` rule
  ///      permits: `unreadCounts`, `lastMessageText`, `lastMessageAt`.
  ///
  /// Step-2 partial failure leaves a stale preview; the message persists
  /// and heals on the next send.
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) async {
    final messageRef = _messagesCol(dmId).doc();
    final messageId = messageRef.id;

    try {
      // Step 1 — write the message document.
      await messageRef.set({
        'messageId': messageId,
        'senderUid': senderUid,
        'senderDisplayName': senderDisplayName,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [senderUid],
      });
      appLogger.debug('DM message written', extra: {'dmId': dmId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'ChatRemoteDatasource.sendMessage step-1 failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      throw ChatDataException('Could not send message: ${e.message}');
    }

    // Step 2 — update the DM parent doc preview fields only.
    // Must use update() (not set/merge) so the write matches the `allow update`
    // rule's affectedKeys().hasOnly(['unreadCounts','lastMessageText','lastMessageAt']).
    final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    try {
      await _dmDoc(dmId).update({
        'unreadCounts.$recipientUid': FieldValue.increment(1),
        'lastMessageText': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      appLogger.debug('DM parent doc updated', extra: {'dmId': dmId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'ChatRemoteDatasource.sendMessage step-2 failed (stale preview)',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      // Not re-thrown: message was written in step 1. Stale preview heals
      // on next send.
    }
  }

  /// Zeroes [uid]'s unread count for [dmId].
  ///
  /// Uses `.update()` with a field-path key so only the caller's own counter
  /// is written. The `allow update` rule (CHAT-M2) permits this single-field
  /// update while blocking callers from touching other participants' counters.
  /// A prior existence check avoids a `not-found` error on `update()`.
  Future<void> markRead(String dmId, String uid) async {
    try {
      final snap = await _dmDoc(dmId).get();
      if (!snap.exists) {
        appLogger.warning(
          'chat_mark_read: DM doc does not exist',
          extra: {'dmId': dmId},
        );
        return;
      }
      await _dmDoc(dmId).update({'unreadCounts.$uid': 0});
      appLogger.debug('chat_mark_read: success', extra: {'dmId': dmId});
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'chat_mark_read: failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e, st, reason: 'chat_mark_read failed',
        );
      }
      throw ChatDataException('Could not mark conversation read: ${e.message}');
    }
  }

  /// Reads both friendship documents to verify the friendship gate
  /// client-side (ADR 0011 constraint — `areFriends()` cannot be called
  /// in rules on this path due to the 10-call budget).
  Future<bool> areFriends(String uidA, String uidB) async {
    try {
      final aDoc = await _firestore
          .doc('users/$uidA/friends/$uidB')
          .get();
      final bDoc = await _firestore
          .doc('users/$uidB/friends/$uidA')
          .get();
      final aStatus = aDoc.data()?['status'] as String?;
      final bStatus = bDoc.data()?['status'] as String?;
      return aStatus == 'accepted' && bStatus == 'accepted';
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'ChatRemoteDatasource.areFriends check failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) await FirebaseCrashlytics.instance.recordError(e, st);
      return false;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Converts Firestore [Timestamp] fields to millisecondsSinceEpoch so that
  /// Freezed models have no dependency on `cloud_firestore`.
  Map<String, dynamic> _convertConversationTimestamps(
    Map<String, dynamic> data,
  ) {
    final result = Map<String, dynamic>.from(data);
    for (final key in const ['createdAt', 'lastMessageAt']) {
      final value = result[key];
      if (value is Timestamp) {
        result[key] = value.millisecondsSinceEpoch;
      }
    }
    // Convert unreadCounts map values to int (Firestore returns them as int
    // but defensively cast).
    if (result['unreadCounts'] is Map) {
      result['unreadCounts'] = Map<String, int>.from(
        (result['unreadCounts'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
    }
    return result;
  }

  Map<String, dynamic> _convertMessageTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    final sentAt = result['sentAt'];
    if (sentAt is Timestamp) {
      result['sentAt'] = sentAt.millisecondsSinceEpoch;
    }
    return result;
  }

  List<DmConversationModel> _parseDmDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            final data = _convertConversationTimestamps(doc.data())
              ..['dmId'] = doc.id;
            return DmConversationModel.fromJson(data);
          } catch (e, st) {
            appLogger.error(
              'Failed to parse DM conversation document',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<DmConversationModel>()
        .toList();
  }

  List<DmMessageModel> _parseMessageDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          try {
            return DmMessageModel.fromJson(
              _convertMessageTimestamps(doc.data()),
            );
          } catch (e, st) {
            appLogger.error(
              'Failed to parse DM message document',
              exception: e,
              stackTrace: st,
              extra: {'docId': doc.id},
            );
            return null;
          }
        })
        .whereType<DmMessageModel>()
        .toList();
  }
}
