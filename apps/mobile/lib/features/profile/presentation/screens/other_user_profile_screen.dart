import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friendship_status.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/providers/outgoing_requests_provider.dart';
import 'package:mobile/features/friends/presentation/widgets/add_friend_button.dart';
import 'package:mobile/features/profile/domain/entities/academic_level.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/profile_score_widget.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/avatar_widget.dart';
import 'package:mobile/shared/widgets/session_card.dart';

/// Displays another user's public profile.
class OtherUserProfileScreen extends ConsumerStatefulWidget {
  const OtherUserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<OtherUserProfileScreen> createState() =>
      _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState
    extends ConsumerState<OtherUserProfileScreen> {
  bool _analyticsLogged = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider(widget.userId));
    final currentUid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    final currentUser = currentUid != null
        ? ref.watch(userProvider(currentUid)).valueOrNull
        : null;

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) {
        appLogger.error(
          'OtherUserProfileScreen: failed to load user',
          exception: e,
          stackTrace: st,
        );
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Failed to load profile')),
        );
      },
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('User not found')),
          );
        }

        // Fire analytics once on first data.
        if (!_analyticsLogged) {
          _analyticsLogged = true;
          appLogger.info(AnalyticsEvents.profileViewedOther);
        }

        return _OtherProfileBody(user: user, currentUser: currentUser);
      },
    );
  }
}

class _OtherProfileBody extends ConsumerWidget {
  const _OtherProfileBody({required this.user, required this.currentUser});

  final UserEntity user;
  final UserEntity? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    // Public sessions only — memberUids arrayContains queries on another user's
    // private sessions are denied by Firestore rules, so we use the safe
    // public-only provider and derive completedCount from it client-side.
    final sessionsAsync = ref.watch(sessionsByUserProvider(user.uid));
    final completedAsync = ref.watch(completedSessionsProvider(user.uid));
    final currentUserId =
        ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';

    final sessions = sessionsAsync.valueOrNull ?? [];
    final sessionCount = sessions.length;
    // completedSessionsProvider is owner-scoped; fall back to counting ended
    // sessions from the public list when it errors (permission denied).
    final completedCount =
        completedAsync.valueOrNull?.length ??
        sessions.where((s) => s.status == 'ended').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(user.displayName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar + name + email + bio + faculty
            Center(
              child: Column(
                children: [
                  AvatarWidget(
                    photoUrl: user.photoUrl,
                    displayName: user.displayName,
                  ),
                  const SizedBox(height: 12),
                  Text(user.displayName, style: tt.displayMedium),
                  if (user.faculty.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${user.faculty} · Year ${user.studentYear} · '
                      '${AcademicLevel.fromString(user.academicLevel).displayName}',
                      style: tt.labelLarge?.copyWith(color: AppColors.hint),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                  ),
                  if ((user.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats row — sessions count is live; friends and rating are stubs
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(label: 'Sessions', value: sessionCount.toString()),
                  Container(width: 1, height: 36, color: AppColors.border),
                  _StatItem(
                    label: 'Friends',
                    value:
                        (ref
                                    .watch(friendsProvider(user.uid))
                                    .valueOrNull
                                    ?.length ??
                                0)
                            .toString(),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  ProfileScoreWidget(
                    profileScore: user.profileScore,
                    completedSessionCount: completedCount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Friend actions row — only for other users
            if (currentUser != null && currentUser!.uid != user.uid)
              _FriendActionsRow(currentUser: currentUser!, targetUser: user),
            const SizedBox(height: 28),

            Text(
              "Sessions by ${user.displayName.split(' ').first}",
              style: tt.titleLarge,
            ),
            const SizedBox(height: 12),

            // Sessions list — loading / error / empty / populated.
            sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                appLogger.error(
                  'OtherUserProfileScreen: failed to load sessions',
                  exception: e,
                  stackTrace: st,
                );
                return const Center(child: Text('Failed to load sessions'));
              },
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: AppColors.disabled,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No public sessions',
                            style: tt.bodyMedium?.copyWith(
                              color: AppColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, i) => SessionCard(
                    session: sessions[i],
                    currentUserId: currentUserId,
                    onTap: () => context.push(
                      RouteConstants.sessionDetail.replaceFirst(
                        ':id',
                        sessions[i].sessionId,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Friend action row: derives [FriendshipStatus] from stream providers.
class _FriendActionsRow extends ConsumerWidget {
  const _FriendActionsRow({
    required this.currentUser,
    required this.targetUser,
  });

  final UserEntity currentUser;
  final UserEntity targetUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acceptedList =
        ref.watch(friendsProvider(currentUser.uid)).valueOrNull ?? [];
    final incomingList =
        ref.watch(incomingRequestsProvider(currentUser.uid)).valueOrNull ?? [];
    final outgoingList =
        ref.watch(outgoingRequestsProvider(currentUser.uid)).valueOrNull ?? [];

    final FriendshipStatus status;
    if (acceptedList.any((f) => f.friendUid == targetUser.uid)) {
      status = FriendshipStatus.friends;
    } else if (incomingList.any((f) => f.initiatorUid == targetUser.uid)) {
      status = FriendshipStatus.requestReceived;
    } else if (outgoingList.any((f) => f.friendUid == targetUser.uid)) {
      status = FriendshipStatus.requestSent;
    } else {
      status = FriendshipStatus.notFriends;
    }

    return Row(
      children: [
        Expanded(
          child: AddFriendButton(
            status: status,
            currentUid: currentUser.uid,
            targetUid: targetUser.uid,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: status == FriendshipStatus.friends
                ? () => context.push('/messages/dm/${targetUser.uid}')
                : null,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Message'),
          ),
        ),
      ],
    );
  }
}

// ── Stat widgets ──────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: tt.displayMedium?.copyWith(color: AppColors.accent)),
        const SizedBox(height: 2),
        Text(label, style: tt.bodyMedium?.copyWith(color: AppColors.hint)),
      ],
    );
  }
}
