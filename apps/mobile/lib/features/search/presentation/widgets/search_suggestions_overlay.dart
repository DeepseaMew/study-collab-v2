import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:mobile/features/search/presentation/providers/recent_searches_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_suggestions_provider.dart';
import 'package:mobile/features/search/presentation/widgets/suggestion_row.dart';

/// Floating white card that appears directly below the search bar when the
/// field is focused.
///
/// - Empty [query]: shows "Recent searches" section (up to 5 items with a
///   "Clear" button) followed by "Suggested hashtags" from loaded sessions.
/// - Non-empty [query]: shows up to 6 live predictions matched against
///   in-memory session data — no new Firestore queries.
/// - [isVisible] false: collapses to [SizedBox.shrink].
///
/// The [onSuggestionTap] callback receives the selected term so the parent
/// screen can fill the search bar and trigger a search.
/// The [onClearRecent] callback fires when the user taps "Clear" in the recent
/// searches header.
class SearchSuggestionsOverlay extends ConsumerWidget {
  const SearchSuggestionsOverlay({
    super.key,
    required this.query,
    required this.isVisible,
    required this.onSuggestionTap,
    required this.onClearRecent,
  });

  final String query;
  final bool isVisible;
  final void Function(String term) onSuggestionTap;
  final VoidCallback onClearRecent;

  static const _kPurple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox.shrink();

    final suggestions = ref.watch(searchSuggestionsProvider(query));
    // Watch recentSearchesProvider so the overlay rebuilds when the user adds
    // or clears recent searches. The actual list is already embedded in
    // [suggestions] by [searchSuggestionsProvider].
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
    ref.watch(recentSearchesProvider(uid));

    return Semantics(
      label: 'Search suggestions',
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(
              color: _kPurple.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: query.isEmpty
                ? _EmptyQueryContent(
                    suggestions: suggestions,
                    onSuggestionTap: onSuggestionTap,
                    onClearRecent: onClearRecent,
                  )
                : _LiveSuggestionsContent(
                    suggestions: suggestions,
                    query: query,
                    onSuggestionTap: onSuggestionTap,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Empty query: recent + hashtags ────────────────────────────────────────────

class _EmptyQueryContent extends StatelessWidget {
  const _EmptyQueryContent({
    required this.suggestions,
    required this.onSuggestionTap,
    required this.onClearRecent,
  });

  final List<SearchSuggestion> suggestions;
  final void Function(String) onSuggestionTap;
  final VoidCallback onClearRecent;

  static const _kPurple = Color(0xFF7C3AED);
  static const _kDivider = Color(0xFFE5E7EB);
  static const _kSectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6B7280),
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    final recentSuggestions = suggestions
        .where((s) => s.type == SuggestionType.recent)
        .toList();
    final hashtagSuggestions = suggestions
        .where((s) => s.type == SuggestionType.hashtag)
        .toList();

    if (recentSuggestions.isEmpty && hashtagSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Recent searches section ─────────────────────────────────────────
        if (recentSuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RECENT SEARCHES', style: _kSectionLabel),
                Semantics(
                  label: 'Clear recent searches',
                  button: true,
                  child: GestureDetector(
                    onTap: onClearRecent,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...recentSuggestions.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SuggestionRowWidget(
                  suggestion: s,
                  query: '',
                  onTap: () => onSuggestionTap(s.displayText),
                ),
                if (idx < recentSuggestions.length - 1)
                  const Divider(height: 0.5, thickness: 0.5, color: _kDivider),
              ],
            );
          }),
        ],

        // ── Suggested hashtags section ──────────────────────────────────────
        if (hashtagSuggestions.isNotEmpty) ...[
          if (recentSuggestions.isNotEmpty)
            const Divider(height: 1, thickness: 1, color: _kDivider),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Text('SUGGESTED HASHTAGS', style: _kSectionLabel),
          ),
          ...hashtagSuggestions.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SuggestionRowWidget(
                  suggestion: s,
                  query: '',
                  onTap: () => onSuggestionTap(s.displayText),
                ),
                if (idx < hashtagSuggestions.length - 1)
                  const Divider(height: 0.5, thickness: 0.5, color: _kDivider),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ── Non-empty query: live predictions ────────────────────────────────────────

class _LiveSuggestionsContent extends StatelessWidget {
  const _LiveSuggestionsContent({
    required this.suggestions,
    required this.query,
    required this.onSuggestionTap,
  });

  final List<SearchSuggestion> suggestions;
  final String query;
  final void Function(String) onSuggestionTap;

  static const _kDivider = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    // Hidden live-region for accessibility — announces the count of suggestions
    // whenever the list updates.
    final count = suggestions.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: '$count suggestion${count == 1 ? '' : 's'}',
          child: const SizedBox.shrink(),
        ),
        ...suggestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuggestionRowWidget(
                suggestion: s,
                query: query,
                onTap: () => onSuggestionTap(s.displayText),
              ),
              if (idx < suggestions.length - 1)
                const Divider(height: 0.5, thickness: 0.5, color: _kDivider),
            ],
          );
        }),
      ],
    );
  }
}
