import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_filter_provider.freezed.dart';
part 'search_filter_provider.g.dart';

/// Value object that captures the state of the four quick-filter chips on the
/// search screen. All fields default to false (no chip selected).
@freezed
abstract class QuickFilters with _$QuickFilters {
  const factory QuickFilters({
    /// "Today" chip — filters sessions scheduled for today only.
    @Default(false) bool today,

    /// "This Week" chip — filters sessions within the current calendar week.
    @Default(false) bool thisWeek,

    /// "My Level" chip — filters sessions matching the current user's academic
    /// level. Resolved to [academicLevel] in [QuickFilterNotifier.toggle].
    @Default(false) bool myLevel,

    /// "Friends" chip — reserved, UI-only toggle.
    @Default(false) bool friends,
  }) = _QuickFilters;
}

/// Manages the state of the four quick-filter chips.
///
/// [keepAlive] is true so that selections survive back-navigation and are
/// restored when the user returns to the search screen (Nielsen #3 — User
/// control and freedom). ADR 0010 Sub-decision 1.
@Riverpod(keepAlive: true)
class QuickFilterNotifier extends _$QuickFilterNotifier {
  @override
  QuickFilters build() => const QuickFilters();

  /// Toggles the chip identified by [key].
  ///
  /// Valid keys: `'today'`, `'thisWeek'`, `'myLevel'`, `'friends'`.
  ///
  /// For `'myLevel'`, reads [userProvider] to resolve the current user's
  /// academic level; the resolved value is used by [_SearchScreenState] when
  /// composing the [SearchFilter] passed to [SearchNotifier].
  ///
  /// For `'friends'`:
  /// // TODO: wire Friends filter once following list ADR is defined
  void toggle(String key) {
    switch (key) {
      case 'today':
        state = state.copyWith(today: !state.today);
      case 'thisWeek':
        state = state.copyWith(thisWeek: !state.thisWeek);
      case 'myLevel':
        // Reading userProvider here to trigger resolution; the screen composes
        // the SearchFilter with the resolved academicLevel from userProvider.
        final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid;
        if (uid != null) {
          // Read user to warm the cache; actual resolution happens in the screen.
          ref.read(userProvider(uid));
        }
        state = state.copyWith(myLevel: !state.myLevel);
      case 'friends':
        // TODO: wire Friends filter once following list ADR is defined
        state = state.copyWith(friends: !state.friends);
    }
  }

  /// Resets all chips to their default (unselected) state.
  void reset() {
    state = const QuickFilters();
  }
}

/// Manages the set of selected subject chips.
///
/// Each subject value is a lowercase string matched against session hashtags
/// (AND logic — a session must contain ALL selected subjects).
///
/// [keepAlive] is true so that selections survive back-navigation (Nielsen #3).
/// ADR 0010 Sub-decision 1.
@Riverpod(keepAlive: true)
class SubjectFilterNotifier extends _$SubjectFilterNotifier {
  @override
  Set<String> build() => const {};

  /// Toggles [subject] in the active set.
  ///
  /// If [subject] is already selected it is removed; otherwise it is added.
  void toggle(String subject) {
    final current = Set<String>.from(state);
    if (current.contains(subject)) {
      current.remove(subject);
    } else {
      current.add(subject);
    }
    state = current;
  }

  /// Removes all selected subjects, returning to the "All" state.
  void clear() {
    state = const {};
  }
}
