import 'package:flutter/foundation.dart';

/// Structured logger for Study Collab.
///
/// This is the ONLY logging call site in the entire codebase.
/// Never call [print] or [debugPrint] directly — always use this logger.
///
/// Rules:
/// - Use [debug] for development-time traces that are noise in production.
/// - Use [info] for significant lifecycle events (app start, navigation, init).
/// - Use [warning] for recoverable unexpected states (cache miss, write blocked).
/// - Use [error] for caught exceptions that are not expected in normal flow.
/// - Never include PII (email addresses, UIDs, names) in any message or extra map.
final appLogger = _AppLogger();

final class _AppLogger {
  void debug(String message, {Map<String, Object?>? extra}) {
    if (kDebugMode) {
      _emit('DEBUG', message, extra);
    }
  }

  void info(String message, {Map<String, Object?>? extra}) {
    _emit('INFO', message, extra);
  }

  void warning(String message, {Map<String, Object?>? extra}) {
    _emit('WARNING', message, extra);
  }

  void error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
    Map<String, Object?>? extra,
  }) {
    _emit('ERROR', message, extra);
    if (exception != null) {
      // In debug builds, surface the full exception for developer visibility.
      if (kDebugMode) {
        debugPrint('[ERROR] exception: $exception');
        if (stackTrace != null) {
          debugPrint('[ERROR] stackTrace: $stackTrace');
        }
      }
    }
  }

  void _emit(String level, String message, Map<String, Object?>? extra) {
    final buffer = StringBuffer('[$level] $message');
    if (extra != null && extra.isNotEmpty) {
      buffer.write(' | ');
      buffer.write(extra.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }
    // Route all output through debugPrint so it is captured by the Flutter
    // log listener and suppressed in release builds when kDebugMode is false.
    debugPrint(buffer.toString());
  }
}
