import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_sharing_flag_provider.g.dart';

/// Returns whether the Note-Sharing feature is enabled via Firebase Remote
/// Config (ADR 0008 sub-decision 4).
///
/// Synchronous read of the already-activated Remote Config value.
/// Defaults to [false] before the first successful fetch (safe-off-by-default).
///
/// [remoteConfigStartupProvider] must have been awaited before this provider
/// is read — guaranteed by the [ProviderContainer] in `main.dart`'s
/// `_bootstrap()`.
@riverpod
bool noteSharingEnabled(NoteSharingEnabledRef ref) {
  return FirebaseRemoteConfig.instance.getBool('note_sharing_enabled');
}
