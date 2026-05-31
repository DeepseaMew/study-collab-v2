import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/hosted_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/subject_colors.dart';
import 'package:mobile/shared/widgets/session_card.dart';

// ── Subject constants ─────────────────────────────────────────────────────────

const _kSubjects = [
  'chemistry',
  'mathematics',
  'physics',
  'computer science',
  'economics',
  'biology',
  'english',
  'other',
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// My Sessions tab screen.
///
/// Three tabs driven by ADR 0003 sub-decision 1:
///   - Upcoming   → watchUpcomingSessions (client-side status != 'ended' filter)
///   - Completed  → watchCompletedSessions
///   - My Sessions → watchHostedSessions
///
/// AppBar carries only the gradient title. Search bar and TabBar live below
/// it in the body on a white background. Create action is a FAB at bottom-center.
///
/// Route: `/my-sessions` (bottom-nav tab 4)
class MySessionsScreen extends ConsumerStatefulWidget {
  const MySessionsScreen({super.key});

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _search = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _fieldFocused = false;
  Set<String> _selectedSubjects = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() => _fieldFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value.toLowerCase());
    appLogger.debug(AnalyticsEvents.mySessionsSearched);
  }

  void _onTabChanged(int index) {
    appLogger.debug(AnalyticsEvents.mySessionsTabSwitched);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;

    // ── Collect hashtags from all loaded streams for the suggestion dropdown ──
    final allHashtags = <String>{};
    if (me != null) {
      for (final session
          in ref.watch(upcomingSessionsProvider(me.uid)).valueOrNull ??
              <SessionEntity>[]) {
        allHashtags.addAll(session.hashtags);
      }
      for (final session
          in ref.watch(completedSessionsProvider(me.uid)).valueOrNull ??
              <SessionEntity>[]) {
        allHashtags.addAll(session.hashtags);
      }
      for (final session
          in ref.watch(hostedSessionsProvider(me.uid)).valueOrNull ??
              <SessionEntity>[]) {
        allHashtags.addAll(session.hashtags);
      }
    }

    // ── Hashtag suggestions filtered by current query ─────────────────────────
    final rawQuery = _query.replaceFirst('#', '');
    final hashtagSuggestions = rawQuery.isEmpty
        ? <String>[]
        : allHashtags
              .where((h) => h.contains(rawQuery.toLowerCase()))
              .take(6)
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7143BF), AppColors.accent],
            ),
          ),
        ),
        title: const Text(
          'My Sessions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar — white background ─────────────────────────────
          ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search sessions...',
                  hintStyle: const TextStyle(
                    color: AppColors.hint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.hint,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.hint,
                          ),
                          onPressed: () {
                            _search.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Hashtag suggestion dropdown ───────────────────────────────
          if (_fieldFocused && hashtagSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tag in hashtagSuggestions)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _search.text = '#$tag';
                        _onSearchChanged('#$tag');
                        _focusNode.unfocus();
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tag,
                              size: 16,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 8),
                            Text(tag, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // ── Subject filter chips — white background ───────────────────
          ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 10,
                children: [
                  // "All" chip
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedSubjects = {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSubjects.isEmpty
                            ? const Color(0xFF7C3AED)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedSubjects.isEmpty
                              ? const Color(0xFF7C3AED)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: _selectedSubjects.isEmpty
                              ? Colors.white
                              : AppColors.hint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Subject chips
                  for (final subject in _kSubjects)
                    Builder(
                      builder: (_) {
                        final colors = subjectColor(subject);
                        final isSelected = _selectedSubjects.contains(subject);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedSubjects = Set.from(_selectedSubjects)
                                  ..remove(subject);
                              } else {
                                _selectedSubjects = Set.from(_selectedSubjects)
                                  ..add(subject);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.border
                                  : colors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(
                                color: isSelected ? Colors.white : colors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // ── TabBar — white background ─────────────────────────────────
          ColoredBox(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              onTap: _onTabChanged,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.hint,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
                Tab(text: 'My Sessions'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: me == null
                ? const Center(
                    child: Text(
                      'Sign in to see your sessions.',
                      style: TextStyle(color: AppColors.hint, fontSize: 14),
                    ),
                  )
                : TabBarView(
                    controller: _tab,
                    children: [
                      _SessionList(
                        stream: ref.watch(upcomingSessionsProvider(me.uid)),
                        query: _query,
                        selectedSubjects: _selectedSubjects,
                        currentUserId: me.uid,
                        emptyMessage: 'No upcoming sessions.',
                        pushHostRoute: false,
                      ),
                      _SessionList(
                        stream: ref.watch(completedSessionsProvider(me.uid)),
                        query: _query,
                        selectedSubjects: _selectedSubjects,
                        currentUserId: me.uid,
                        emptyMessage: 'No completed sessions.',
                        pushHostRoute: false,
                        isCompleted: true,
                      ),
                      _SessionList(
                        stream: ref.watch(hostedSessionsProvider(me.uid)),
                        query: _query,
                        selectedSubjects: _selectedSubjects,
                        currentUserId: me.uid,
                        emptyMessage: 'No hosted sessions.',
                        pushHostRoute: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Session list pane ─────────────────────────────────────────────────────────

class _SessionList extends ConsumerStatefulWidget {
  const _SessionList({
    required this.stream,
    required this.query,
    required this.selectedSubjects,
    required this.currentUserId,
    required this.emptyMessage,
    required this.pushHostRoute,
    this.isCompleted = false,
  });

  final AsyncValue<List<SessionEntity>> stream;
  final String query;
  final Set<String> selectedSubjects;
  final String currentUserId;
  final String emptyMessage;
  final bool pushHostRoute;
  final bool isCompleted;

  @override
  ConsumerState<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends ConsumerState<_SessionList> {
  int _page = 0;
  static const _kPageSize = 4;

  @override
  void didUpdateWidget(_SessionList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) setState(() => _page = 0);
  }

  @override
  Widget build(BuildContext context) {
    return widget.stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        appLogger.error(
          'MySessionsScreen list error',
          exception: e,
          stackTrace: st,
        );
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load sessions.',
              style: TextStyle(color: AppColors.hint, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      data: (sessions) {
        final filtered = sessions.where((s) {
          final rawQuery = widget.query.replaceFirst('#', '');
          final matchesQuery =
              rawQuery.isEmpty ||
              s.title.toLowerCase().contains(rawQuery) ||
              s.hashtags.any((h) => h.contains(rawQuery));
          final matchesSubjects =
              widget.selectedSubjects.isEmpty ||
              widget.selectedSubjects.every((sub) => s.hashtags.contains(sub));
          return matchesQuery && matchesSubjects;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.folder_open_outlined,
                    size: 48,
                    color: AppColors.hint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.emptyMessage,
                    style: const TextStyle(color: AppColors.hint, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (_page * _kPageSize >= filtered.length && filtered.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _page = 0);
          });
        }
        final totalPages = max(1, (filtered.length / _kPageSize).ceil());
        final pageItems = filtered.sublist(
          _page * _kPageSize,
          min((_page + 1) * _kPageSize, filtered.length),
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
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
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
            return SessionCard(
              session: session,
              currentUserId: widget.currentUserId,
              onTap: () {
                final route = widget.pushHostRoute
                    ? RouteConstants.mySessionHost
                    : RouteConstants.mySessionMember;
                context.push(
                  route.replaceFirst(':id', session.sessionId),
                  extra: <String, dynamic>{'isCompleted': widget.isCompleted},
                );
              },
            );
          },
        );
      },
    );
  }
}
