import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/logger.dart';

/// Default notification preference values (ADR 0013 SD6).
const Map<String, bool> _defaultPreferences = {
  'allNotifications': true,
  'joinRequestAlerts': true,
  'friendRequests': true,
  'ratingAvailable': true,
};

const String _kPreferencesKey = 'notification_preferences';

/// Local storage data source for notification preferences (ADR 0013 SD6).
///
/// Uses [FlutterSecureStorage] to persist a JSON-encoded map of boolean
/// preference flags. Actors always write notifications regardless of recipient
/// preferences; these flags are applied client-side as a display filter only.
class NotificationPreferencesDatasource {
  NotificationPreferencesDatasource(this._storage);

  /// Creates a [NotificationPreferencesDatasource] wired to the default
  /// [FlutterSecureStorage] instance.
  factory NotificationPreferencesDatasource.create() =>
      NotificationPreferencesDatasource(const FlutterSecureStorage());

  final FlutterSecureStorage _storage;

  /// Reads preferences from secure storage. Returns defaults when the key is
  /// absent or the stored JSON cannot be parsed.
  Future<Map<String, bool>> readPreferences() async {
    try {
      final raw = await _storage.read(key: _kPreferencesKey);
      if (raw == null) return Map.of(_defaultPreferences);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      // Merge with defaults so new keys introduced in updates get default values.
      return {
        ..._defaultPreferences,
        for (final entry in decoded.entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      };
    } catch (e, st) {
      appLogger.error(
        'NotificationPreferencesDatasource: failed to read preferences; returning defaults',
        exception: e,
        stackTrace: st,
      );
      return Map.of(_defaultPreferences);
    }
  }

  /// Writes the full preferences map to secure storage.
  Future<void> writePreferences(Map<String, bool> preferences) async {
    try {
      await _storage.write(
        key: _kPreferencesKey,
        value: jsonEncode(preferences),
      );
    } catch (e, st) {
      appLogger.error(
        'NotificationPreferencesDatasource: failed to write preferences',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
