import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/chat/data/datasources/session_chat_remote_datasource.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';

/// Implements [SessionChatRepository] using [SessionChatRemoteDatasource].
///
/// Converts models to domain entities. Records non-fatal Crashlytics events at
/// every caught exception site (ADR 0012 / Crashlytics house rules).
class SessionChatRepositoryImpl implements SessionChatRepository {
  SessionChatRepositoryImpl(this._datasource);

  final SessionChatRemoteDatasource _datasource;

  @override
  Stream<List<SessionMessage>> streamMessages(
    String sessionId, {
    int limit = 50,
  }) {
    return _datasource
        .streamMessages(sessionId, limit: limit)
        .map((models) => models.map((m) => m.toEntity()).toList())
        .handleError((Object e, StackTrace st) {
          appLogger.error(
            'session_chat_repo: streamMessages error sessionId=$sessionId',
            exception: e,
            stackTrace: st,
          );
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.recordError(
              e,
              st,
              reason: 'session_chat streamMessages error',
            );
          }
        });
  }

  @override
  Future<List<SessionMessage>> getOlderMessages(
    String sessionId,
    DateTime startAfter, {
    int limit = 50,
  }) async {
    try {
      final models = await _datasource.getOlderMessages(
        sessionId,
        startAfter,
        limit: limit,
      );
      return models.map((m) => m.toEntity()).toList();
    } catch (e, st) {
      appLogger.error(
        'session_chat_repo: getOlderMessages error sessionId=$sessionId',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'session_chat getOlderMessages error',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) async {
    try {
      await _datasource.sendMessage(
        sessionId: sessionId,
        memberUids: memberUids,
        senderUid: senderUid,
        senderDisplayName: senderDisplayName,
        sessionTitle: sessionTitle,
        text: text,
      );
    } catch (e, st) {
      appLogger.error(
        'session_chat_repo: sendMessage error sessionId=$sessionId',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'session_chat sendMessage error',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> markSessionRead(String sessionId, String uid) async {
    try {
      await _datasource.markSessionRead(sessionId, uid);
    } catch (e, st) {
      appLogger.error(
        'session_chat_repo: markSessionRead error sessionId=$sessionId',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'session_chat markSessionRead error',
        );
      }
      rethrow;
    }
  }

  @override
  Stream<List<GroupChatSummary>> streamGroupChatSummaries(String uid) {
    return _datasource
        .streamGroupChatSummaries(uid)
        .map((models) => models.map((m) => m.toEntity()).toList())
        .handleError((Object e, StackTrace st) {
          appLogger.error(
            'session_chat_repo: streamGroupChatSummaries error',
            exception: e,
            stackTrace: st,
          );
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.recordError(
              e,
              st,
              reason: 'session_chat streamGroupChatSummaries error',
            );
          }
        });
  }
}
