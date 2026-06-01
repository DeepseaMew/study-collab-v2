import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<ConnectivityResult>> connectivityStream(
  ConnectivityStreamRef ref,
) => Connectivity().onConnectivityChanged;

/// Returns `true` when at least one network interface is reachable.
/// Defaults to `true` before the first connectivity event arrives.
@Riverpod(keepAlive: true)
bool isOnline(IsOnlineRef ref) {
  final results = ref.watch(connectivityStreamProvider).valueOrNull;
  if (results == null) return true;
  return results.any((r) => r != ConnectivityResult.none);
}
