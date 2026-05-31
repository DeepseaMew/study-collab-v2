import 'dart:async';
import 'dart:math' show max, min;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/search_error.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/presentation/providers/filter_provider.dart';
import 'package:mobile/features/search/presentation/providers/recent_searches_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_provider.dart';
import 'package:mobile/features/search/presentation/widgets/active_filter_summary.dart';
import 'package:mobile/features/search/presentation/widgets/quick_filter_chips.dart';
import 'package:mobile/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:mobile/features/search/presentation/widgets/search_suggestions_overlay.dart';
import 'package:mobile/features/search/presentation/widgets/subject_filter_chips.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/session_card.dart';

/// Full-screen search screen pushed over the bottom nav bar (ADR 0010).
///
/// Route: `/search` — top-level GoRoute, not inside the StatefulShellRoute.
///
/// Behaviour when [FeatureFlags.searchEnhancementsEnabled] is false:
///   bare search bar + flat [ListView.builder] of public scheduled sessions.
///
/// Behaviour when flag is true:
///   tip bar, subject chips, quick-filter chips, active-filter summary,
///   result count, zero-results state, network-error state with retry,
///   search suggestions overlay (recent searches + live predictions).
///
/// Debounce: 300 ms [Timer] for main search, 150 ms [Timer] for suggestions.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _headerKey = GlobalKey();

  Timer? _debounceTimer;
  Timer? _suggestionDebounce;

  bool _fieldFocused = false;
  String _suggestionQuery = '';
  bool _isHostSearch = false;
  String _hostQueryStr = '';

  // Cached header height for overlay positioning.
  double _headerHeight = 0;

  static const _kPurple = Color(0xFF7C3AED);
  static const _kPurpleBg = Color(0xFFF5F4FF);
  static const _kTipBg = Color(0xFFEDE9FE);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSearch();
      _measureHeader();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionDebounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _measureHeader() {
    final ctx = _headerKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final height = box.size.height;
    if (height != _headerHeight) {
      setState(() => _headerHeight = height);
    }
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_fieldFocused == focused) return;
    if (focused) {
      setState(() => _fieldFocused = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
    } else {
      // Delay collapsing the overlay so any suggestion tap fires before the
      // widget tree is removed. Without this, the InkWell.onTap is swallowed
      // because the overlay disappears the moment focus leaves the text field.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _fieldFocused = false);
        }
      });
    }
  }

  void _onQueryChanged(String value) {
    // Main search debounce (300 ms).
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _triggerSearch);

    // Suggestion debounce (150 ms).
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _suggestionQuery = _controller.text.trim());
    });
  }

  /// Builds a composed [SearchFilter] from all three notifiers plus the
  /// text field, then dispatches to [SearchNotifier].
  void _triggerSearch() {
    final rawText = _controller.text.trim();
    final subjects = ref.read(subjectFilterNotifierProvider);
    final quickFilters = ref.read(quickFilterNotifierProvider);

    // Route "@handle" to host search, "#tag" to the hashtag filter (Index 3),
    // and plain text to the keyword query.
    String? textQuery;
    String? hashtagQuery;
    bool isHostSearch = false;
    String hostQueryStr = '';

    if (rawText.startsWith('@')) {
      // Pass the full "@handle" string so _matchesFilter can detect it.
      textQuery = rawText.isEmpty ? null : rawText;
      isHostSearch = true;
      hostQueryStr = rawText.substring(1).trim();
    } else if (rawText.startsWith('#')) {
      final tag = rawText.substring(1).trim().toLowerCase();
      if (tag.isNotEmpty) hashtagQuery = tag;
    } else {
      textQuery = rawText.isEmpty ? null : rawText;
    }

    setState(() {
      _isHostSearch = isHostSearch;
      _hostQueryStr = hostQueryStr;
    });

    // Resolve myLevel to the user's actual academicLevel string.
    String? resolvedAcademicLevel;
    if (quickFilters.myLevel) {
      final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid;
      if (uid != null) {
        resolvedAcademicLevel =
            ref.read(userProvider(uid)).valueOrNull?.academicLevel;
      }
    }

    // Map quick-filter booleans to SearchDateRange.
    SearchDateRange? dateRange;
    if (quickFilters.today) {
      dateRange = SearchDateRange.today;
    } else if (quickFilters.thisWeek) {
      dateRange = SearchDateRange.thisWeek;
    } else if (quickFilters.myLevel) {
      dateRange = SearchDateRange.myLevel;
    }
    // Friends chip is UI-only for now — no dateRange mapping.

    final composedFilter = SearchFilter(
      query: textQuery,
      hashtag: hashtagQuery,
      subjects: subjects.isEmpty ? null : subjects,
      dateRange: dateRange,
      // Inject resolved academicLevel so repository can apply myLevel filter.
      academicLevel: resolvedAcademicLevel,
    );

    ref.read(searchNotifierProvider.notifier).search(composedFilter);

    appLogger.debug(
      AnalyticsEvents.searchPerformed,
      extra: {
        'has_keyword': textQuery != null,
        'has_hashtag': composedFilter.hashtag != null,
        'has_level_filter': composedFilter.academicLevel != null,
        'has_year_filter': composedFilter.studentYear != null,
      },
    );
  }

  /// Resets all filters and re-runs an empty search.
  void _resetAll() {
    _controller.clear();
    ref.read(subjectFilterNotifierProvider.notifier).clear();
    ref.read(quickFilterNotifierProvider.notifier).reset();
    ref.read(searchFilterNotifierProvider.notifier).clearFilter();
    setState(() {
      _isHostSearch = false;
      _hostQueryStr = '';
    });
    _triggerSearch();
  }

  /// Persists [term] to secure storage via [RecentSearchesNotifier].
  Future<void> _addToRecent(String term) async {
    if (term.isEmpty) return;
    final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    await ref.read(recentSearchesNotifierProvider(uid).notifier).add(term);
  }

  /// Clears all recent searches for the current user.
  Future<void> _clearRecent() async {
    final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    await ref.read(recentSearchesNotifierProvider(uid).notifier).clear();
  }

  /// Called when the user taps a suggestion.
  ///
  /// Fills the text field with [term], persists it to recent searches,
  /// unfocuses the field (which hides the overlay), and triggers a search
  /// immediately (no debounce).
  void _onSuggestionTap(String term) {
    // Strip leading '#' when the user tapped a hashtag suggestion — the
    // search field should receive the raw hashtag text as typed.
    _controller.text = term;
    // Move cursor to end.
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _addToRecent(term);
    setState(() {
      _suggestionQuery = term.trim();
    });
    _triggerSearch();
    appLogger.debug(
      'SearchScreen: suggestion tapped',
      extra: {'type': 'suggestion'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
    final searchAsync = ref.watch(searchNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _kPurpleBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Search sessions'),
      ),
      body: Stack(
        children: [
          // ── Main scrollable content ────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search bar + result count ────────────────────────────────
              Container(
                key: _headerKey,
                color: _kPurpleBg,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchBarWidget(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) {
                        _focusNode.unfocus();
                        setState(() => _fieldFocused = false);
                        _triggerSearch();
                      },
                    ),
                    const SizedBox(height: 6),
                    if (FeatureFlags.searchEnhancementsEnabled)
                      Semantics(
                        liveRegion: true,
                        child: searchAsync.valueOrNull != null
                            ? Text(
                                '${searchAsync.valueOrNull!.length} '
                                'session${searchAsync.valueOrNull!.length == 1 ? '' : 's'} found',
                                style: const TextStyle(
                                  color: _kPurple,
                                  fontSize: 11,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),

              // ── Tip bar ─────────────────────────────────────────────────
              if (FeatureFlags.searchEnhancementsEnabled)
                Container(
                  width: double.infinity,
                  color: _kTipBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: _kPurple),
                      SizedBox(width: 6),
                      Text(
                        'Tip: use #hashtag or @host to narrow results',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),

              // ── Subject chips ────────────────────────────────────────────
              if (FeatureFlags.searchEnhancementsEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SubjectFilterChipsWidget(
                    onFilterChanged: _triggerSearch,
                  ),
                ),

              // ── Quick filter chips ───────────────────────────────────────
              if (FeatureFlags.searchEnhancementsEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: QuickFilterChipsWidget(
                    onFilterChanged: _triggerSearch,
                  ),
                ),

              // ── Active filter summary ────────────────────────────────────
              if (FeatureFlags.searchEnhancementsEnabled)
                ActiveFilterSummaryWidget(onResetAll: _resetAll),

              // ── Results ─────────────────────────────────────────────────
              Expanded(
                child: searchAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: _kPurple),
                  ),
                  error: (error, st) {
                    if (error is! SearchError) {
                      FirebaseCrashlytics.instance.recordError(
                        error,
                        st,
                        reason: 'SearchScreen unexpected error',
                      );
                    }
                    appLogger.error(
                      'SearchScreen: error state',
                      exception: error,
                      stackTrace: st,
                    );
                    return _ErrorState(
                      error: error,
                      onRetry: () {
                        appLogger.debug(AnalyticsEvents.searchRetryTapped);
                        _triggerSearch();
                      },
                    );
                  },
                  data: (sessions) {
                    if (_isHostSearch) {
                      return _HostSearchResults(
                        sessions: sessions,
                        hostQuery: _hostQueryStr,
                        uid: uid,
                      );
                    }
                    if (sessions.isEmpty) return const _EmptyState();
                    return _ResultsList(sessions: sessions, uid: uid);
                  },
                ),
              ),
            ],
          ),

          // ── Suggestions overlay ────────────────────────────────────────────
          // Positioned immediately below the purple header, floating on top of
          // the filter chips and results list.
          if (FeatureFlags.searchEnhancementsEnabled && _headerHeight > 0)
            Positioned(
              top: _headerHeight - 12,
              left: 0,
              right: 0,
              child: SearchSuggestionsOverlay(
                query: _suggestionQuery,
                isVisible: _fieldFocused,
                onSuggestionTap: _onSuggestionTap,
                onClearRecent: _clearRecent,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends ConsumerStatefulWidget {
  const _ResultsList({required this.sessions, required this.uid});

  final List<SessionEntity> sessions;
  final String uid;

  @override
  ConsumerState<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends ConsumerState<_ResultsList> {
  int _page = 0;
  static const _kPageSize = 4;

  @override
  void didUpdateWidget(_ResultsList old) {
    super.didUpdateWidget(old);
    if (old.sessions != widget.sessions) setState(() => _page = 0);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = max(
      1,
      (widget.sessions.length / _kPageSize).ceil(),
    );
    final pageItems = widget.sessions.sublist(
      _page * _kPageSize,
      min((_page + 1) * _kPageSize, widget.sessions.length),
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == pageItems.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed:
                      _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('Prev'),
                ),
                Text(
                  '${_page + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.hint,
                  ),
                ),
                TextButton.icon(
                  onPressed: _page < totalPages - 1
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Next'),
                ),
              ],
            ),
          );
        }
        final session = pageItems[i];
        final isPending =
            ref
                .watch(
                  myPendingRequestProvider(session.sessionId, widget.uid),
                )
                .valueOrNull ??
            false;
        return SessionCard(
          session: session,
          currentUserId: widget.uid,
          isPending: isPending,
          showJoinButton: true,
          onTap: () {
            appLogger.debug(AnalyticsEvents.searchResultTapped);
            context.push(
              RouteConstants.sessionDetail.replaceFirst(
                ':id',
                session.sessionId,
              ),
            );
          },
          onJoinTap: isPending
              ? null
              : () {
                  appLogger.debug(AnalyticsEvents.searchResultTapped);
                  context.push(
                    RouteConstants.sessionDetail.replaceFirst(
                      ':id',
                      session.sessionId,
                    ),
                  );
                },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.hint),
            const SizedBox(height: 16),
            Text('No sessions found', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or adjust your filters.',
              style: tt.bodyMedium?.copyWith(color: AppColors.hint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  String get _message {
    if (error is SearchQueryTooShort) {
      return 'Please enter at least 2 characters to search.';
    }
    if (error is SearchOfflineNotSupported) {
      return 'Search requires an internet connection.\nPlease check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  IconData get _icon {
    if (error is SearchOfflineNotSupported) return Icons.wifi_off;
    return Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 48, color: AppColors.hint),
            const SizedBox(height: 16),
            Text(
              _message,
              style: tt.bodyMedium?.copyWith(color: AppColors.hint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Host search results ───────────────────────────────────────────────────────

class _HostSearchResults extends ConsumerStatefulWidget {
  const _HostSearchResults({
    required this.sessions,
    required this.hostQuery,
    required this.uid,
  });

  final List<SessionEntity> sessions;
  final String hostQuery;
  final String uid;

  @override
  ConsumerState<_HostSearchResults> createState() => _HostSearchResultsState();
}

class _HostSearchResultsState extends ConsumerState<_HostSearchResults> {
  int _page = 0;
  static const _kPageSize = 4;

  @override
  void didUpdateWidget(_HostSearchResults old) {
    super.didUpdateWidget(old);
    if (old.sessions != widget.sessions) setState(() => _page = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      final tt = Theme.of(context).textTheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search, size: 48, color: AppColors.hint),
              const SizedBox(height: 16),
              Text(
                'No user found matching @${widget.hostQuery}',
                style: tt.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final host = widget.sessions.first;
    final totalPages = max(1, (widget.sessions.length / _kPageSize).ceil());
    final pageItems = widget.sessions.sublist(
      _page * _kPageSize,
      min((_page + 1) * _kPageSize, widget.sessions.length),
    );
    // 4 fixed header slots: profile card, spacer, section label, spacer.
    const headerCount = 4;
    final showPagination = totalPages > 1;
    final totalCount = headerCount + pageItems.length + (showPagination ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HostProfileCard(
            hostUid: host.hostUid,
            displayName: host.hostDisplayName,
            photoUrl: host.hostPhotoUrl,
            sessionCount: widget.sessions.length,
          );
        }
        if (index == 1) return const SizedBox(height: 16);
        if (index == 2) {
          return Text(
            'Sessions by @${widget.hostQuery}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.hint,
              letterSpacing: 0.3,
            ),
          );
        }
        if (index == 3) return const SizedBox(height: 8);

        // Pagination row as the last item.
        if (showPagination && index == totalCount - 1) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Prev'),
              ),
              Text(
                '${_page + 1} / $totalPages',
                style: const TextStyle(fontSize: 13, color: AppColors.hint),
              ),
              TextButton.icon(
                onPressed: _page < totalPages - 1
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
              ),
            ],
          );
        }

        final session = pageItems[index - headerCount];
        final isPending =
            ref
                .watch(myPendingRequestProvider(session.sessionId, widget.uid))
                .valueOrNull ??
            false;
        return SessionCard(
          session: session,
          currentUserId: widget.uid,
          isPending: isPending,
          showJoinButton: true,
          onTap: () {
            appLogger.debug(AnalyticsEvents.searchResultTapped);
            context.push(
              RouteConstants.sessionDetail
                  .replaceFirst(':id', session.sessionId),
            );
          },
          onJoinTap: isPending
              ? null
              : () {
                  appLogger.debug(AnalyticsEvents.searchResultTapped);
                  context.push(
                    RouteConstants.sessionDetail
                        .replaceFirst(':id', session.sessionId),
                  );
                },
        );
      },
    );
  }
}

// ── Host profile card ─────────────────────────────────────────────────────────

class _HostProfileCard extends ConsumerWidget {
  const _HostProfileCard({
    required this.hostUid,
    required this.displayName,
    required this.photoUrl,
    required this.sessionCount,
  });

  final String hostUid;
  final String displayName;
  final String? photoUrl;
  final int sessionCount;

  static const _kPurple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(hostUid));
    final score = userAsync.valueOrNull?.profileScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: '$displayName profile photo',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.secondary,
                  backgroundImage:
                      photoUrl != null && photoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl!)
                          : null,
                  child: photoUrl == null || photoUrl!.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _kPurple,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$sessionCount session${sessionCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.hint,
                          ),
                        ),
                        if (score != null) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '·',
                            style: TextStyle(color: AppColors.hint),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(score * 100).round()}% rating',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.hint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/profile/$hostUid'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPurple,
                side: const BorderSide(color: _kPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('View Profile'),
            ),
          ),
        ],
      ),
    );
  }
}
