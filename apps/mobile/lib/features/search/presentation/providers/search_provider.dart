import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/search/data/datasources/search_datasource.dart';
import 'package:mobile/features/search/data/repositories/search_repository_impl.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/domain/repositories/search_repository.dart';
import 'package:mobile/features/search/domain/usecases/search_sessions_usecase.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

/// Provides the [SearchRepository] implementation wired to Firestore.
@riverpod
SearchRepository searchRepository(SearchRepositoryRef ref) {
  return SearchRepositoryImpl(SearchDatasource.withDefaultFirestore());
}

/// Provides the [SearchSessionsUseCase].
@riverpod
SearchSessionsUseCase searchSessionsUseCase(SearchSessionsUseCaseRef ref) {
  return SearchSessionsUseCase(ref.watch(searchRepositoryProvider));
}

/// Manages the async state of a search query result.
///
/// Exposes [search] to trigger a new search with a given [SearchFilter].
/// Starts in the loading state (empty list).
///
/// [keepAlive] is true so that the search results survive a back-navigation
/// and are restored when the user returns to the search route (Nielsen #3 —
/// User control and freedom). ADR 0010 Sub-decision 1.
@Riverpod(keepAlive: true)
class SearchNotifier extends _$SearchNotifier {
  @override
  FutureOr<List<SessionEntity>> build() => [];

  /// Executes a search for [filter] via [SearchSessionsUseCase].
  ///
  /// Results are post-filtered to exclude sessions the current user has
  /// already joined or is hosting — the search screen shows only joinable
  /// sessions, matching the home screen behaviour.
  Future<void> search(SearchFilter filter) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final currentUid =
          ref.read(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
      final results =
          await ref.read(searchSessionsUseCaseProvider).call(filter);
      // Host search (@handle) must not suppress sessions the user already
      // joined — the user may want to browse a host's full session list.
      final isHostSearch = filter.query?.startsWith('@') ?? false;
      if (isHostSearch || currentUid.isEmpty) return results;
      return results
          .where(
            (s) =>
                s.hostUid != currentUid &&
                !s.memberUids.contains(currentUid),
          )
          .toList();
    });
  }
}
