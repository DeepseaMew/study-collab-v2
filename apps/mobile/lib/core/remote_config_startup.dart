import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:mobile/core/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_config_startup.g.dart';

/// Fetches and activates Firebase Remote Config during app startup.
///
/// Must be awaited (via [ProviderContainer]) before [ProviderScope] renders
/// any screen that reads [noteSharingEnabledProvider].
///
/// Sets a 12-hour minimum fetch interval in production and a 10-second fetch
/// timeout, per ADR 0008 sub-decision 4.
@riverpod
Future<void> remoteConfigStartup(RemoteConfigStartupRef ref) async {
  final remoteConfig = FirebaseRemoteConfig.instance;

  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 12),
    ),
  );

  await remoteConfig.setDefaults(const {'rating_enabled': false});

  try {
    await remoteConfig.fetchAndActivate();
    appLogger.info('remote_config: fetchAndActivate succeeded');
  } catch (e, st) {
    // Non-fatal: the app continues with cached/default values.
    appLogger.warning(
      'remote_config: fetchAndActivate failed; using cached or default values',
      extra: {'errorType': e.runtimeType.toString()},
    );
    appLogger.error(
      'remote_config: fetchAndActivate error',
      exception: e,
      stackTrace: st,
    );
  }
}
