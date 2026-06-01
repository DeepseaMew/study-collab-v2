import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/providers/session_chat_providers.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_conversation_tile.dart';
import 'package:mobile/features/chat/presentation/widgets/group_chat_summary_tile.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// The Messages tab screen — shows DM conversations (Individual) and
/// session group chats (Groups) in a two-tab layout.
///
/// Route: `/messages`
/// Analytics:
///   - [AnalyticsEvents.dmConversationListViewed] on first frame (Individual tab).
///   - [AnalyticsEvents.groupsTabViewed] when Groups tab becomes active.
class DmConversationListScreen extends ConsumerStatefulWidget {
  const DmConversationListScreen({super.key});

  @override
  ConsumerState<DmConversationListScreen> createState() =>
      _DmConversationListScreenState();
}

class _DmConversationListScreenState
    extends ConsumerState<DmConversationListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _groupsAnalyticsFired = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appLogger.info(AnalyticsEvents.dmConversationListViewed);
    });
  }

  void _onTabChanged() {
    if (_tabCtrl.index == 1 && !_groupsAnalyticsFired) {
      _groupsAnalyticsFired = true;
      appLogger.info(AnalyticsEvents.groupsTabViewed);
    }
    // Rebuild to update tab badge display.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DmConversation> _filteredDms(
    List<DmConversation> all,
    Map<String, String> nameMap,
  ) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((c) {
      final other = nameMap[c.dmId] ?? '';
      return other.toLowerCase().contains(q);
    }).toList();
  }

  List<GroupChatSummary> _filteredGroups(List<GroupChatSummary> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) => s.sessionTitle.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;
    final unreadGroupTotal = me != null
        ? ref.watch(unreadGroupTotalProvider(me.uid))
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7143BF), AppColors.accent],
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  const Tab(text: 'Individual'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Groups'),
                        if (unreadGroupTotal > 0) ...[
                          const SizedBox(width: 6),
                          _UnreadBadge(count: unreadGroupTotal),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: me == null
          ? const Center(
              child: Text(
                'Sign in to see your messages.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            )
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _IndividualTab(
                  myUid: me.uid,
                  query: _query,
                  filteredDms: _filteredDms,
                ),
                _GroupsTab(
                  myUid: me.uid,
                  query: _query,
                  filteredGroups: _filteredGroups,
                ),
              ],
            ),
    );
  }
}

// ── Unread badge ──────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${count > 99 ? '99+' : count}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Individual tab ────────────────────────────────────────────────────────────

class _IndividualTab extends ConsumerWidget {
  const _IndividualTab({
    required this.myUid,
    required this.query,
    required this.filteredDms,
  });

  final String myUid;
  final String query;
  final List<DmConversation> Function(List<DmConversation>, Map<String, String>)
  filteredDms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosAsync = ref.watch(dmConversationsProvider(myUid));
    final friendsAsync = ref.watch(friendsProvider(myUid));

    return convosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        appLogger.error(
          'DmConversationListScreen load error',
          exception: e,
          stackTrace: st,
        );
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Could not load conversations. Please try again.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.hint),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      data: (convos) {
        final friends = friendsAsync.asData?.value ?? <FriendEntity>[];
        final nameMap = <String, String>{
          for (final f in friends) f.friendUid: f.friendDisplayName,
        };
        final dmNameMap = <String, String>{
          for (final c in convos) c.dmId: nameMap[c.otherUid(myUid)] ?? '',
        };

        final items = filteredDms(convos, dmNameMap);

        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.chat_bubble_outline,
            title: query.isNotEmpty ? 'No results found' : 'No messages yet',
            subtitle: query.isNotEmpty
                ? 'Try a different name'
                : "Start a conversation from someone's profile",
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 76, color: AppColors.border),
          itemBuilder: (ctx, i) {
            final convo = items[i];
            final name = dmNameMap[convo.dmId] ?? '';
            return DmConversationTile(
              conversation: convo,
              myUid: myUid,
              displayName: name,
              onTap: () {
                appLogger.info(AnalyticsEvents.dmConversationOpened);
                ctx.push(
                  '/messages/dm/${convo.dmId}',
                  extra: {
                    'otherUid': convo.otherUid(myUid),
                    'displayName': name,
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Groups tab ────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({
    required this.myUid,
    required this.query,
    required this.filteredGroups,
  });

  final String myUid;
  final String query;
  final List<GroupChatSummary> Function(List<GroupChatSummary>) filteredGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(groupChatSummariesProvider(myUid));

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        appLogger.error('GroupsTab load error', exception: e, stackTrace: st);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Could not load group chats. Please try again.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.hint),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      data: (summaries) {
        final items = filteredGroups(summaries);

        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.group_outlined,
            title: query.isNotEmpty ? 'No results found' : 'No group chats yet',
            subtitle: query.isNotEmpty
                ? 'Try a different session name'
                : 'Join a session to access its group chat',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 76, color: AppColors.border),
          itemBuilder: (ctx, i) {
            final summary = items[i];
            return GroupChatSummaryTile(
              summary: summary,
              onTap: () {
                // Mark read fire-and-forget.
                ref
                    .read(sessionChatActionsNotifierProvider.notifier)
                    .markSessionRead(summary.sessionId, myUid);
                ctx.push('/sessions/${summary.sessionId}/chat');
              },
            );
          },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(icon, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text(title, style: tt.displaySmall),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: tt.bodyMedium?.copyWith(color: AppColors.hint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
