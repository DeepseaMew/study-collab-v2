import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_conversation_tile.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// The Messages tab screen — shows a searchable list of DM conversations.
///
/// Route: `/messages`
/// Analytics: [AnalyticsEvents.dmConversationListViewed] logged on first frame.
class DmConversationListScreen extends ConsumerStatefulWidget {
  const DmConversationListScreen({super.key});

  @override
  ConsumerState<DmConversationListScreen> createState() =>
      _DmConversationListScreenState();
}

class _DmConversationListScreenState
    extends ConsumerState<DmConversationListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appLogger.info(AnalyticsEvents.dmConversationListViewed);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DmConversation> _filtered(
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
      ),
      body: me == null
          ? const Center(
              child: Text(
                'Sign in to see your messages.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            )
          : _Body(
              myUid: me.uid,
              query: _query,
              searchCtrl: _searchCtrl,
              onQueryChanged: (v) => setState(() => _query = v),
              filtered: _filtered,
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({
    required this.myUid,
    required this.query,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.filtered,
  });

  final String myUid;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final List<DmConversation> Function(
    List<DmConversation>,
    Map<String, String>,
  ) filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosAsync = ref.watch(dmConversationsProvider(myUid));
    final friendsAsync = ref.watch(friendsProvider(myUid));

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Search conversations...',
              prefixIcon: Icon(Icons.search, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // ── Conversation list ───────────────────────────────────────────────
        Expanded(
          child: convosAsync.when(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.hint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
            data: (convos) {
              // Build a UID→displayName map from the friends list.
              final friends = friendsAsync.asData?.value ?? <FriendEntity>[];
              final nameMap = <String, String>{
                for (final f in friends) f.friendUid: f.friendDisplayName,
              };
              // Map dmId → displayName for the other participant.
              final dmNameMap = <String, String>{
                for (final c in convos)
                  c.dmId: nameMap[c.otherUid(myUid)] ?? '',
              };

              final items = filtered(convos, dmNameMap);

              if (items.isEmpty) {
                return _EmptyState(hasQuery: query.isNotEmpty);
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.border,
                ),
                itemBuilder: (ctx, i) {
                  final convo = items[i];
                  final name = dmNameMap[convo.dmId] ?? '';
                  return DmConversationTile(
                    conversation: convo,
                    myUid: myUid,
                    displayName: name,
                    onTap: () {
                      appLogger.info(AnalyticsEvents.dmConversationOpened);
                      context.push(
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
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

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
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No results found' : 'No messages yet',
            style: tt.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different name'
                : "Start a conversation from someone's profile",
            style: tt.bodyMedium?.copyWith(color: AppColors.hint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
