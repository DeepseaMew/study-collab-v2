import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Google Calendar API datasource.
///
/// Translates [SessionEntity] objects into Google Calendar [Event] patches.
class GcalDatasource {
  GcalDatasource(this._calendarApi, {FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final CalendarApi _calendarApi;
  final FirebaseCrashlytics _crashlytics;

  /// Derives a stable, deterministic Google Calendar event ID from [sessionId].
  ///
  /// Google Calendar event IDs must be lowercase alphanumeric plus hyphens,
  /// 5–1024 characters. We prefix with 'sc' to ensure it never starts with a
  /// digit (some API versions reject those).
  String _eventId(String sessionId) {
    final bytes = utf8.encode(sessionId);
    final digest = sha1.convert(bytes);
    return 'sc${digest.toString()}';
  }

  Event _toEvent(SessionEntity session) {
    final endTime = session.scheduledEndAt ?? session.scheduledAt;
    return Event(
      summary: session.title,
      description:
          '${session.description ?? ''}'
          '\n\nHost: ${session.hostDisplayName}'
          '\nStatus: ${session.status}',
      location: session.location,
      start: EventDateTime(dateTime: session.scheduledAt),
      end: EventDateTime(dateTime: endTime),
    );
  }

  /// Patches a single calendar event for [session].
  ///
  /// Falls back to [events.insert] when the event does not exist yet (404).
  /// The event ID is always 'sc' + sha1hex(sessionId) per ADR 0007.
  Future<void> patchEvent(SessionEntity session) async {
    final id = _eventId(session.sessionId);
    try {
      await _calendarApi.events.patch(_toEvent(session), 'primary', id);
    } on DetailedApiRequestError catch (e, st) {
      if (e.status == 404) {
        // Event does not exist yet in the user's calendar — insert it.
        appLogger.info(
          'gcal_sync: event not found, inserting sessionId=${session.sessionId}',
        );
        try {
          // Set id on the event body so Google Calendar uses our deterministic ID.
          await _calendarApi.events.insert(
            _toEvent(session)..id = id,
            'primary',
          );
        } on DetailedApiRequestError catch (e2, st2) {
          appLogger.error(
            'gcal_sync: events.insert failed errorCode=${e2.status}',
            exception: e2,
            stackTrace: st2,
          );
          if (!kIsWeb) await _crashlytics.recordError(e2, st2);
          throw ApiFailureError('events.insert failed: ${e2.status}');
        }
      } else {
        appLogger.error(
          'gcal_sync: events.patch failed errorCode=${e.status}',
          exception: e,
          stackTrace: st,
        );
        if (!kIsWeb) await _crashlytics.recordError(e, st);
        throw ApiFailureError('events.patch failed: ${e.status}');
      }
    }
  }

  /// Pushes all [sessions] to GCal, counting successes and failures.
  Future<SyncResult> syncSessions(List<SessionEntity> sessions) async {
    int synced = 0;
    int failed = 0;
    for (final s in sessions) {
      try {
        await patchEvent(s);
        synced++;
      } on ApiFailureError {
        failed++;
      }
    }
    appLogger.info('gcal_sync: sync complete synced=$synced failed=$failed');
    return SyncResult(
      syncedCount: synced,
      failedCount: failed,
      syncedAt: DateTime.now(),
    );
  }
}
