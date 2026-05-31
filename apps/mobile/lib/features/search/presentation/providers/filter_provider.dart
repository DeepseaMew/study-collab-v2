import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filter_provider.g.dart';

/// Manages the active [SearchFilter] for the search screen.
///
/// Reads [userProvider] directly (Q3 answer) to resolve [SearchDateRange.myLevel]
/// to the current user's [academicLevel] string.
///
/// [keepAlive] is true so that active filter selections survive a back-navigation
/// and are restored when the user returns (Nielsen #3 — User control and freedom).
/// ADR 0010 Sub-decision 1.
@Riverpod(keepAlive: true)
class SearchFilterNotifier extends _$SearchFilterNotifier {
  @override
  SearchFilter build() => const SearchFilter();

  /// Applies [filter] as the new active filter.
  ///
  /// When [filter.dateRange] is [SearchDateRange.myLevel], resolves the current
  /// user's [academicLevel] and injects it into [filter.academicLevel].
  void updateFilter(SearchFilter filter) {
    if (filter.dateRange == SearchDateRange.myLevel) {
      final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid;
      final academicLevel = uid != null
          ? ref.read(userProvider(uid)).valueOrNull?.academicLevel
          : null;

      state = filter.copyWith(
        academicLevel: academicLevel ?? filter.academicLevel,
      );
    } else {
      state = filter;
    }
  }

  /// Resets all active filters to the empty default.
  void clearFilter() {
    state = const SearchFilter();
  }
}
