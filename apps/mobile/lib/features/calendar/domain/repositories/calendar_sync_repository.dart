import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Domain repository interface for Google Calendar sync operations.
///
/// Zero Flutter or Firebase imports — pure Dart.
abstract interface class CalendarSyncRepository {
  /// Returns [true] when a Google account is already silently signed-in.
  Future<bool> isConnected();

  /// Runs the Google Sign-In OAuth flow, verifies the signed-in email matches
  /// [expectedEmail], and requests the calendar.events scope.
  ///
  /// Throws [EmailMismatchError] when emails differ.
  /// Throws [CancelledError] when the user dismisses the consent screen.
  Future<void> connect(String expectedEmail);

  /// Revokes the Google Sign-In session and removes the last-sync timestamp.
  Future<void> disconnect();

  /// Pushes [sessions] to the signed-in user's Google Calendar as events.
  ///
  /// Throws [CancelledError] when no current user session exists.
  Future<SyncResult> syncSessions(List<SessionEntity> sessions);
}
