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
import 'package:mobile/shared/widgets/session_card.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
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
                        currentUserId: me.uid,
                        emptyMessage: 'No upcoming sessions.',
                        pushHostRoute: false,
                      ),
                      _SessionList(
                        stream: ref.watch(completedSessionsProvider(me.uid)),
                        query: _query,
                        currentUserId: me.uid,
                        emptyMessage: 'No completed sessions.',
                        pushHostRoute: false,
                        isCompleted: true,
                      ),
                      _SessionList(
                        stream: ref.watch(hostedSessionsProvider(me.uid)),
                        query: _query,
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

class _SessionList extends ConsumerWidget {
  const _SessionList({
    required this.stream,
    required this.query,
    required this.currentUserId,
    required this.emptyMessage,
    required this.pushHostRoute,
    this.isCompleted = false,
  });

  final AsyncValue<List<SessionEntity>> stream;
  final String query;
  final String currentUserId;
  final String emptyMessage;
  final bool pushHostRoute;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return stream.when(
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
        final filtered = query.isEmpty
            ? sessions
            : sessions
                  .where(
                    (s) =>
                        s.title.toLowerCase().contains(query) ||
                        s.hashtags.any((h) => h.contains(query)),
                  )
                  .toList();

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
                    emptyMessage,
                    style: const TextStyle(color: AppColors.hint, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final session = filtered[i];
            return SessionCard(
              session: session,
              currentUserId: currentUserId,
              onTap: () {
                final route = pushHostRoute
                    ? RouteConstants.mySessionHost
                    : RouteConstants.mySessionMember;
                context.push(
                  route.replaceFirst(':id', session.sessionId),
                  extra: isCompleted,
                );
              },
            );
          },
        );
      },
    );
  }
}
