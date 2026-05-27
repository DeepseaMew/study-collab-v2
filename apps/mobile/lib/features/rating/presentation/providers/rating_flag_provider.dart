import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_flag_provider.g.dart';

/// Returns whether the Rating feature is enabled via Firebase Remote Config.
///
/// Defaults to [false] before the first successful fetch (safe-off-by-default).
/// [remoteConfigStartupProvider] must have been awaited before this provider
/// is read.
@riverpod
bool ratingEnabled(RatingEnabledRef ref) =>
    FirebaseRemoteConfig.instance.getBool('rating_enabled');
