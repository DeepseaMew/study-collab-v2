import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Full member list for a session.
///
/// Route: `/sessions/:id/members`
class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(sessionMembersProvider(sessionId));
    final sessionAsync = ref.watch(sessionStreamProvider(sessionId));
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final hostUid = sessionAsync.valueOrNull?.hostUid;
    // Only true once both providers have resolved to non-null data — guards
    // against a race where sessionAsync is still loading and hostUid is null,
    // which would cause isViewerHost to be false for one or more frames.
    final isViewerHost = sessionAsync.hasValue &&
        currentUserAsync.hasValue &&
        hostUid != null &&
        currentUser != null &&
        hostUid == currentUser.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Members',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          appLogger.error(
            'MembersListScreen failed to load members',
            exception: e,
            stackTrace: st,
            extra: {'sessionId': sessionId},
          );
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load members.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text(
                'No members yet.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            );
          }
          // Host always first; remaining members preserve original order.
          final sorted = [
            ...members.where((m) => m.uid == hostUid),
            ...members.where((m) => m.uid != hostUid),
          ];
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _MemberTile(
              member: sorted[i],
              isSessionHost: sorted[i].uid == hostUid,
              showFaculty: isViewerHost,
            ),
          );
        },
      ),
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isSessionHost,
    required this.showFaculty,
  });

  final UserEntity member;
  final bool isSessionHost;
  final bool showFaculty;

  @override
  Widget build(BuildContext context) {
    final initial =
        member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.secondary,
            backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(member.photoUrl!)
                : null,
            child: member.photoUrl == null || member.photoUrl!.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSessionHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Host',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (showFaculty && member.faculty.isNotEmpty)
                  Text(
                    member.faculty,
                    style: const TextStyle(
                      color: AppColors.hint,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
