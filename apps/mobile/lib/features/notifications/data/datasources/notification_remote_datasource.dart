import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/notifications/data/models/notification_model.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';

/// Firestore data source for the `users/{uid}/notifications` subcollection
/// (ADR 0013).
///
/// All path strings come from [FirestorePaths]. No domain types cross this
/// boundary — callers in [NotificationRepositoryImpl] handle model-to-entity
/// conversion.
class NotificationRemoteDatasource {
  NotificationRemoteDatasource(this._firestore);

  /// Creates a [NotificationRemoteDatasource] wired to the default
  /// [FirebaseFirestore] instance.
  factory NotificationRemoteDatasource.withDefaultFirestore() =>
      NotificationRemoteDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notifCol(String uid) =>
      _firestore.collection(FirestorePaths.userNotificationsCollection(uid));

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Streams the latest 50 notifications for [uid] ordered by `createdAt` desc.
  ///
  /// Parse failures on individual documents are logged and skipped; the stream
  /// does not fail for a single bad document (ADR 0013 SD3).
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _notifCol(
      uid,
    ).orderBy('createdAt', descending: true).limit(50).snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            try {
              final data = _convertTimestamp(doc.data());
              return NotificationModel.fromJson(data);
            } catch (e, st) {
              appLogger.error(
                'Failed to parse notification document',
                exception: e,
                stackTrace: st,
                extra: {'docId': doc.id},
              );
              return null;
            }
          })
          .whereType<NotificationModel>()
          .toList();
    });
  }

  /// Streams the count of unread notifications for [uid] (ADR 0013 SD2).
  ///
  /// Uses Index 13: `isRead ASC, createdAt DESC`.
  Stream<int> streamUnreadCount(String uid) {
    return _notifCol(uid)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Batch-marks all unread documents for [uid] as `isRead: true` (ADR 0013 SD5).
  ///
  /// Capped at 50 documents (same as the stream cap) — a single Firestore batch
  /// operation.
  Future<void> markAllRead(String uid) async {
    try {
      final snap = await _notifCol(
        uid,
      ).where('isRead', isEqualTo: false).limit(50).get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      appLogger.info(
        'markAllRead batch committed',
        extra: {'count': snap.docs.length},
      );
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'markAllRead batch failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      throw DataException('Could not mark notifications as read: ${e.message}');
    } catch (e, st) {
      appLogger.error(
        'markAllRead unexpected error',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      rethrow;
    }
  }

  /// Writes a notification document to `users/{recipientUid}/notifications/`.
  ///
  /// `isRead` is always `false` on create; `createdAt` uses
  /// `FieldValue.serverTimestamp()` (no `== request.time` check in rules per
  /// ADR 0011 web constraint).
  Future<void> createNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    required NotificationType type,
    String? sessionId,
    String? sessionTitle,
  }) async {
    try {
      final ref = _notifCol(recipientUid).doc();
      final notifId = ref.id;
      final data = <String, dynamic>{
        'notifId': notifId,
        'type': type.toFirestoreString(),
        'actorUid': actorUid,
        'actorDisplayName': actorDisplayName,
        'sessionId': sessionId,
        'sessionTitle': sessionTitle,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await ref.set(data);
      appLogger.info(
        'Notification created',
        extra: {'type': type.toFirestoreString()},
      );
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'createNotification failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      throw DataException('Could not create notification: ${e.message}');
    } catch (e, st) {
      appLogger.error(
        'createNotification unexpected error',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      rethrow;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns a shallow copy of [data] with the `createdAt` field preserved as
  /// a Firestore [Timestamp] (passed through unchanged for the json converter).
  Map<String, dynamic> _convertTimestamp(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    final value = result['createdAt'];
    if (value is Timestamp) {
      result['createdAt'] = value;
    }
    return result;
  }
}
