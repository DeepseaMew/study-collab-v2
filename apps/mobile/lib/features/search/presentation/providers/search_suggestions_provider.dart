import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:mobile/features/search/presentation/providers/recent_searches_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_suggestions_provider.g.dart';

/// Maximum number of live-prediction suggestions shown when the query is
/// non-empty.
const _kMaxLiveSuggestions = 6;

/// Maximum number of recent-term suggestions shown when the query is empty.
const _kMaxRecentSuggestions = 5;

/// Maximum number of popular-hashtag suggestions shown below recent terms.
const _kMaxHashtagSuggestions = 8;

/// Builds a list of [SearchSuggestion] items for the current [query].
///
/// - When [query] is empty: returns up to [_kMaxRecentSuggestions] recent
///   searches (type [SuggestionType.recent]) followed by up to
///   [_kMaxHashtagSuggestions] popular hashtags (type [SuggestionType.hashtag])
///   extracted from already-loaded session data in memory.
///
/// - When [query] is non-empty: matches session titles, hashtags, and host
///   display names from in-memory session data — NO new Firestore query.
///   Returns up to [_kMaxLiveSuggestions] results ranked with exact prefix
///   matches first.
///
/// Debounce (150 ms) is applied in the screen, not here.
@riverpod
List<SearchSuggestion> searchSuggestions(
  SearchSuggestionsRef ref,
  String query,
) {
  final sessions = ref.watch(searchNotifierProvider).valueOrNull ?? [];

  if (query.isEmpty) {
    return _buildEmptySuggestions(ref, sessions);
  }
  return _buildLiveSuggestions(query, sessions);
}

// ── Empty-query path ──────────────────────────────────────────────────────────

List<SearchSuggestion> _buildEmptySuggestions(
  SearchSuggestionsRef ref,
  List<SessionEntity> sessions,
) {
  final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
  final recentAsync = ref.watch(recentSearchesProvider(uid));
  final recentTerms = recentAsync.valueOrNull ?? [];

  final suggestions = <SearchSuggestion>[];

  // Recent searches — newest first, capped at [_kMaxRecentSuggestions].
  for (final term in recentTerms.take(_kMaxRecentSuggestions)) {
    suggestions.add(
      SearchSuggestion(displayText: term, type: SuggestionType.recent),
    );
  }

  // Popular hashtags — ranked by frequency across loaded sessions.
  final hashtagFrequency = <String, int>{};
  for (final session in sessions) {
    for (final tag in session.hashtags) {
      hashtagFrequency[tag] = (hashtagFrequency[tag] ?? 0) + 1;
    }
  }

  final sortedTags = hashtagFrequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (final entry in sortedTags.take(_kMaxHashtagSuggestions)) {
    suggestions.add(
      SearchSuggestion(
        displayText: '#${entry.key}',
        type: SuggestionType.hashtag,
      ),
    );
  }

  return suggestions;
}

// ── Non-empty-query path ──────────────────────────────────────────────────────

List<SearchSuggestion> _buildLiveSuggestions(
  String query,
  List<SessionEntity> sessions,
) {
  final q = query.toLowerCase();

  // Candidates collected in two passes: prefix matches (rank 0) before
  // substring matches (rank 1).
  final prefixMatches = <SearchSuggestion>[];
  final substringMatches = <SearchSuggestion>[];

  // Deduplicate display texts to avoid identical rows.
  final seen = <String>{};

  void addUnique(SearchSuggestion s, bool isPrefix) {
    if (seen.contains(s.displayText)) return;
    seen.add(s.displayText);
    if (isPrefix) {
      prefixMatches.add(s);
    } else {
      substringMatches.add(s);
    }
  }

  for (final session in sessions) {
    // Session title
    final titleLower = session.title.toLowerCase();
    if (titleLower.contains(q)) {
      addUnique(
        SearchSuggestion(
          displayText: session.title,
          type: SuggestionType.sessionName,
          subject: session.hashtags.isNotEmpty ? session.hashtags.first : null,
        ),
        titleLower.startsWith(q),
      );
    }

    // Hashtags — strip leading '#' from the query if present for matching.
    final tagQuery = q.startsWith('#') ? q.substring(1) : q;
    for (final tag in session.hashtags) {
      if (tag.contains(tagQuery)) {
        addUnique(
          SearchSuggestion(
            displayText: '#$tag',
            type: SuggestionType.hashtag,
          ),
          tag.startsWith(tagQuery),
        );
      }
    }

    // Host display name
    final hostLower = session.hostDisplayName.toLowerCase();
    if (hostLower.contains(q)) {
      addUnique(
        SearchSuggestion(
          displayText: session.hostDisplayName,
          type: SuggestionType.host,
        ),
        hostLower.startsWith(q),
      );
    }
  }

  return [
    ...prefixMatches,
    ...substringMatches,
  ].take(_kMaxLiveSuggestions).toList();
}
