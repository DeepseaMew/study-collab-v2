import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/profile/domain/entities/academic_level.dart';
import 'package:mobile/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/avatar_widget.dart';
import 'package:mobile/shared/widgets/session_card.dart';

/// The current user's own profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    if (uid == null) {
      // Not signed in — redirect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(RouteConstants.signIn);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userAsync = ref.watch(userProvider(uid));

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) {
        appLogger.error(
          'ProfileScreen: failed to load current user',
          exception: e,
          stackTrace: st,
        );
        return const Scaffold(
          body: Center(child: Text('Failed to load profile')),
        );
      },
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RouteConstants.signIn);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _ProfileBody(user: user);
      },
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.user});

  final UserEntity user;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _analyticsLogged = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final tt = Theme.of(context).textTheme;

    // Fire analytics once on first real data.
    if (!_analyticsLogged) {
      _analyticsLogged = true;
      appLogger.info(AnalyticsEvents.profileViewedOwn);
    }

    final friendsAsync = ref.watch(friendsProvider(user.uid));
    final friendsCount =
        friendsAsync.valueOrNull?.length.toString() ?? '0';

    final upcomingAsync = ref.watch(upcomingSessionsProvider(user.uid));
    final completedAsync = ref.watch(completedSessionsProvider(user.uid));
    final upcomingSessions = upcomingAsync.valueOrNull ?? [];
    final completedSessions = completedAsync.valueOrNull ?? [];
    final allSessions = [...upcomingSessions, ...completedSessions];
    final sessionCount = allSessions.length.toString();

    final avatarUploadState = ref.watch(avatarUploadProvider);
    final localBytesAsync = ref.watch(localBytesStreamProvider(user.uid));
    final localBytes = localBytesAsync.valueOrNull != null
        ? Uint8List.fromList(localBytesAsync.valueOrNull!)
        : null;

    // Show error snackbar if upload failed.
    ref.listen<AsyncValue<void>>(avatarUploadProvider, (_, next) {
      if (next is AsyncError) {
        appLogger.error(
          'ProfileScreen: avatar upload failed',
          exception: next.error,
          stackTrace: next.stackTrace,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload avatar. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        titleSpacing: 20,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RouteConstants.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Avatar + name + email + bio + faculty
          Center(
            child: Column(
              children: [
                // Avatar with tap-to-upload and camera badge.
                GestureDetector(
                  onTap: avatarUploadState.isLoading
                      ? null
                      : () => ref
                            .read(avatarUploadProvider.notifier)
                            .pickAndUpload(user.uid),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarWidget(
                        photoUrl: user.photoUrl,
                        displayName: user.displayName,
                        localBytes: localBytes,
                        isLoading: avatarUploadState.isLoading,
                      ),
                      // Camera badge — bottom-right corner.
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Semantics(
                          label: 'Change avatar',
                          button: true,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.displayName, style: tt.displayMedium),
                if (user.faculty.isNotEmpty) ...[
                  const SizedBox(height: 2),
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
                    style: tt.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
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
                _StatItem(label: 'Sessions', value: sessionCount),
                Container(width: 1, height: 36, color: AppColors.border),
                Semantics(
                  label: 'Friends count, tap to view friends list',
                  button: true,
                  child: GestureDetector(
                    onTap: () => context.push(RouteConstants.friends),
                    child: _StatItem(label: 'Friends', value: friendsCount),
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                const _RatingStatItem(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit profile button
          OutlinedButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditProfileSheet(user: user),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile'),
          ),
          const SizedBox(height: 28),

          Text('Session History', style: tt.titleLarge),
          const SizedBox(height: 12),

          if (upcomingAsync.isLoading || completedAsync.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (allSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.history_outlined,
                      size: 48,
                      color: AppColors.disabled,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No session history yet',
                      style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allSessions.length > 5 ? 5 : allSessions.length,
              itemBuilder: (_, i) {
                final session = allSessions[i];
                return SessionCard(
                  session: session,
                  currentUserId: user.uid,
                  onTap: () {
                    final route = session.hostUid == user.uid
                        ? RouteConstants.mySessionHost
                        : RouteConstants.mySessionMember;
                    context.push(
                      route.replaceFirst(':id', session.sessionId),
                    );
                  },
                );
              },
            ),
            if (allSessions.length > 5) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => context.push(RouteConstants.mySessions),
                  child: const Text('See All'),
                ),
              ),
            ],
          ],
        ],
        ),
      ),
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
        Text(
          value,
          style: tt.displayMedium?.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tt.bodyMedium?.copyWith(color: AppColors.hint),
        ),
      ],
    );
  }
}

class _RatingStatItem extends StatelessWidget {
  const _RatingStatItem();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.thumb_up_rounded,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              'N/A',
              style: tt.displayMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'from 0 sessions',
          style: tt.bodySmall?.copyWith(color: AppColors.hint),
        ),
      ],
    );
  }
}
