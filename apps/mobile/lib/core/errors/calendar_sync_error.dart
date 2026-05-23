/// Sealed error hierarchy for Google Calendar sync operations.
///
/// Zero Flutter or Firebase imports — pure Dart.
/// Never throw strings — always throw a subclass of [CalendarSyncError].
sealed class CalendarSyncError {}

/// The Google account email does not match the user's KMUTT account email.
final class EmailMismatchError extends CalendarSyncError {}

/// A Google Calendar API call failed.
final class ApiFailureError extends CalendarSyncError {
  /// Human-readable reason — must not contain PII.
  final String message;
  // ignore: prefer_const_constructors_in_immutables
  ApiFailureError(this.message);
}

/// The user cancelled the Google Sign-In consent screen or scope request.
final class CancelledError extends CalendarSyncError {}
