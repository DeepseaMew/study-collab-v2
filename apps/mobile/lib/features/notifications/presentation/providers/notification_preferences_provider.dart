import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/notifications/data/datasources/notification_preferences_datasource.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_preferences_provider.g.dart';

/// AsyncNotifier that owns notification preference state (ADR 0013 SD6).
///
/// State is a `Map<String, bool>` — the full preferences map from secure
/// storage. Defaults to all `true` when the key is absent.
///
/// [toggle] updates a single preference key; when the master toggle
/// (`allNotifications`) is set to `false`, all other toggles are also set to
/// `false` as per ADR 0013 settings-screen spec.
@riverpod
class NotificationPreferencesNotifier
    extends _$NotificationPreferencesNotifier {
  late final NotificationPreferencesDatasource _datasource;

  @override
  Future<Map<String, bool>> build() async {
    _datasource = NotificationPreferencesDatasource.create();
    return _datasource.readPreferences();
  }

  /// Toggles a single preference key.
  ///
  /// When [key] is `allNotifications` and [value] is `false`, all other keys
  /// are also set to `false`. Analytics event is fired with the preference key
  /// and new value (no PII).
  Future<void> toggle(String key, {required bool value}) async {
    final current = state.valueOrNull ?? <String, bool>{};
    final updated = Map<String, bool>.from(current);

    if (key == 'allNotifications' && !value) {
      // Master off: suppress all displays.
      for (final k in updated.keys) {
        updated[k] = false;
      }
    } else {
      updated[key] = value;
    }

    state = AsyncData(updated);
    appLogger.info(
      AnalyticsEvents.notificationPreferenceChanged,
      extra: {'preference_key': key, 'new_value': value},
    );

    try {
      await _datasource.writePreferences(updated);
    } catch (e, st) {
      appLogger.error(
        'NotificationPreferencesNotifier: failed to persist preference',
        exception: e,
        stackTrace: st,
      );
      // Revert to the previous state on write failure.
      state = AsyncData(current);
    }
  }
}
