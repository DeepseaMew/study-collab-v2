import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';

/// Firestore implementation of [NotificationRepository] (ADR 0013).
///
/// No Firestore types appear at the [NotificationRepository] interface
/// boundary. Crashlytics is called at every caught exception site behind
/// `if (!kIsWeb)`.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._datasource);

  final NotificationRemoteDatasource _datasource;

  @override
  Stream<List<NotificationEntity>> streamNotifications(String recipientUid) {
    return _datasource
        .streamNotifications(recipientUid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<int> streamUnreadCount(String recipientUid) {
    return _datasource.streamUnreadCount(recipientUid);
  }

  @override
  Future<void> markAllRead(String recipientUid) async {
    try {
      await _datasource.markAllRead(recipientUid);
      appLogger.info('markAllRead completed via repository');
    } catch (e, st) {
      appLogger.error(
        'NotificationRepositoryImpl.markAllRead failed',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      rethrow;
    }
  }

  @override
  Future<void> createNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    required NotificationType type,
    String? sessionId,
    String? sessionTitle,
  }) async {
    try {
      await _datasource.createNotification(
        recipientUid: recipientUid,
        actorUid: actorUid,
        actorDisplayName: actorDisplayName,
        type: type,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
      );
      appLogger.info(
        'createNotification completed via repository',
        extra: {'type': type.toFirestoreString()},
      );
    } catch (e, st) {
      appLogger.error(
        'NotificationRepositoryImpl.createNotification failed',
        exception: e,
        stackTrace: st,
        extra: {'type': type.toFirestoreString()},
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      rethrow;
    }
  }
}
