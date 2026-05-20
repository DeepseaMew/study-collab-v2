import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/presentation/providers/friend_action_provider.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/widgets/friend_list_tile.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Tabbed Friends screen.
///
/// Tab 0: accepted friends list.
/// Tab 1: incoming + outgoing request counts; taps navigate to
///         [FriendRequestsScreen] for the full list.
///
/// Route: `/friends`
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: me == null
            ? null
            : [
                _RequestsBadge(currentUid: me.uid),
              ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: me == null
          ? const Center(
              child: Text(
                'Sign in to see your friends.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            )
          : TabBarView(
              controller: _tab,
              children: [
                _FriendsList(currentUid: me.uid),
                _RequestsTab(currentUid: me.uid),
              ],
            ),
    );
  }
}

// ── Friends list tab ──────────────────────────────────────────────────────────

class _FriendsList extends ConsumerWidget {
  const _FriendsList({required this.currentUid});
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider(currentUid));

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        appLogger.error(
          'FriendsScreen friends list error',
          exception: e,
          stackTrace: st,
        );
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load friends.',
              style: TextStyle(color: AppColors.hint, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: AppColors.hint,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No friends yet. Search for peers to add!',
                    style: TextStyle(color: AppColors.hint, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (_, i) {
            final friend = friends[i];
            return FriendListTile(
              friend: friend,
              onUnfriend: () async {
                await ref
                    .read(friendActionNotifierProvider.notifier)
                    .unfriend(
                      currentUid: currentUid,
                      friendUid: friend.friendUid,
                    );
                final state = ref.read(friendActionNotifierProvider);
                if (state.hasError && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not unfriend. Please try again.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.currentUid});
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingRequestsProvider(currentUid));

    final incomingCount = incomingAsync.asData?.value.length ?? 0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_add_outlined,
            size: 48,
            color: AppColors.hint,
          ),
          const SizedBox(height: 12),
          Text(
            incomingCount > 0
                ? 'You have $incomingCount pending request${incomingCount == 1 ? '' : 's'}.'
                : 'No pending requests.',
            style: const TextStyle(color: AppColors.hint, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () =>
                context.push(RouteConstants.friendRequests),
            child: const Text('View All Requests'),
          ),
        ],
      ),
    );
  }
}

// ── Requests badge icon button ─────────────────────────────────────────────────

class _RequestsBadge extends ConsumerWidget {
  const _RequestsBadge({required this.currentUid});
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingRequestsProvider(currentUid));
    final count = incomingAsync.asData?.value.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.error,
        child: IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () =>
              context.push(RouteConstants.friendRequests),
          tooltip: 'Friend requests',
        ),
      ),
    );
  }
}
