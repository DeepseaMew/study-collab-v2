import 'package:mobile/features/search/data/datasources/recent_search_local_datasource.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recent_searches_provider.g.dart';

/// Provides the [RecentSearchLocalDatasource] instance.
@riverpod
RecentSearchLocalDatasource recentSearchLocalDatasource(
  RecentSearchLocalDatasourceRef ref,
) {
  return RecentSearchLocalDatasource.withDefaults();
}

/// Reads the recent search terms for [uid] from local secure storage.
///
/// Auto-disposes when the consumer is no longer active.
@riverpod
Future<List<String>> recentSearches(RecentSearchesRef ref, String uid) {
  return ref.watch(recentSearchLocalDatasourceProvider).getRecentSearches(uid);
}

/// Manages write operations on recent searches for a given [uid].
///
/// Exposes [add] and [clear] so the search screen can persist and wipe recent
/// terms without duplicating datasource access logic.
///
/// State is `void` — reads are handled by [recentSearchesProvider] which
/// re-evaluates when [ref.invalidate] is called after a write.
@riverpod
class RecentSearchesNotifier extends _$RecentSearchesNotifier {
  @override
  void build(String uid) {}

  /// Adds [term] to recent searches and invalidates the read provider so the
  /// overlay refreshes immediately.
  Future<void> add(String term) async {
    final ds = ref.read(recentSearchLocalDatasourceProvider);
    await ds.addRecentSearch(uid, term);
    ref.invalidate(recentSearchesProvider(uid));
  }

  /// Clears all recent searches for [uid] and invalidates the read provider.
  Future<void> clear() async {
    final ds = ref.read(recentSearchLocalDatasourceProvider);
    await ds.clearRecentSearches(uid);
    ref.invalidate(recentSearchesProvider(uid));
  }
}
