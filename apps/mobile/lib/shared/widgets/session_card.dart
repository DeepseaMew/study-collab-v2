import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/subject_colors.dart';

/// Shared session card widget used by My Sessions, Dashboard, and Search.
///
/// The detail screen pushed on tap is determined entirely by the calling
/// context — not by inspecting [session.hostUid] at render time.
/// See ADR 0003 sub-decision 4.
///
/// Constructor follows the spec in ADR 0003 "Session card widget" section.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.onTap,
    this.showJoinButton = false,
    this.onJoinTap,
    this.isPending = false,
  });

  final SessionEntity session;
  final String currentUserId;
  final VoidCallback onTap;

  /// When `true`, a "Request to Join" button is rendered at the bottom.
  /// Used by Home and Search screens only.
  final bool showJoinButton;

  /// Called when the Join button is tapped. Required when [showJoinButton] is true.
  final VoidCallback? onJoinTap;

  /// When `true`, the join button shows a "Pending..." disabled state.
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final isHost = session.hostUid == currentUserId;
    final subjectLabel = session.hashtags.isNotEmpty
        ? session.hashtags.first
        : session.academicLevel;
    final progress = session.capacity > 0
        ? (session.participantCount / session.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: 'Session: ${session.title}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row: subject chip + status badge + lock + 3-dot menu
                Row(
                  children: [
                    _SubjectChip(label: subjectLabel),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      label: isHost ? 'Hosting' : 'Joined',
                      color: isHost ? AppColors.accent : AppColors.success,
                    ),
                    if (session.visibility == 'private') ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: AppColors.hint,
                      ),
                    ],
                    const Spacer(),
                    _ThreeDotMenu(
                      session: session,
                      isHost: isHost,
                      currentUserId: currentUserId,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Title ─────────────────────────────────────────────────────
                Text(
                  session.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // ── Host name ─────────────────────────────────────────────────
                GestureDetector(
                  onTap: session.hostUid != currentUserId
                      ? () => context.push('/profile/${session.hostUid}')
                      : null,
                  child: Row(
                    children: [
                      _HostAvatar(
                        displayName: session.hostDisplayName,
                        photoUrl: session.hostPhotoUrl,
                        radius: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        session.hostDisplayName,
                        style: const TextStyle(
                          color: AppColors.hint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // ── Date / time ───────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppColors.hint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.scheduledEndAt != null
                          ? '${DateFormatter.relativeDate(session.scheduledAt)}  '
                                '${DateFormatter.timeRange(session.scheduledAt, session.scheduledEndAt!)}'
                          : DateFormatter.relativeDate(session.scheduledAt),
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Location ──────────────────────────────────────────────────
                if (session.location.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.hint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          session.location,
                          style: const TextStyle(
                            color: AppColors.hint,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // ── Description ───────────────────────────────────────────────
                if (session.description != null &&
                    session.description!.isNotEmpty) ...[
                  Text(
                    session.description!,
                    style: const TextStyle(color: AppColors.hint, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],

                const SizedBox(height: 4),

                // ── Member count + spots left ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${session.participantCount}/${session.capacity} members',
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      session.isFull
                          ? 'Full'
                          : '${session.spotsLeft} spots left',
                      style: TextStyle(
                        color: session.isFull
                            ? AppColors.error
                            : AppColors.hint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Capacity progress bar ─────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    color: AppColors.accent,
                    backgroundColor: AppColors.secondary,
                    minHeight: 5,
                  ),
                ),

                // ── Join button (home/search only) ────────────────────────────
                if (showJoinButton) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPending
                            ? AppColors.disabled
                            : AppColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isPending ? null : onJoinTap,
                      child: Text(
                        isPending ? 'Pending...' : 'Request to Join',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Subject chip ───────────────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = subjectColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Host avatar ───────────────────────────────────────────────────────────────

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({
    required this.displayName,
    required this.photoUrl,
    required this.radius,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
        backgroundColor: AppColors.secondary,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondary,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Three-dot context menu ────────────────────────────────────────────────────

enum _CardMenuAction { edit, delete, leave }

class _ThreeDotMenu extends ConsumerWidget {
  const _ThreeDotMenu({
    required this.session,
    required this.isHost,
    required this.currentUserId,
  });

  final SessionEntity session;
  final bool isHost;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_CardMenuAction>(
      tooltip: isHost ? 'Session options' : 'Member options',
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.hint),
      onSelected: (action) {
        switch (action) {
          case _CardMenuAction.edit:
            context.push(
              RouteConstants.sessionEdit.replaceFirst(':id', session.sessionId),
            );
          case _CardMenuAction.delete:
            _showDeleteDialog(context, ref);
          case _CardMenuAction.leave:
            _showLeaveDialog(context, ref);
        }
      },
      itemBuilder: (_) => isHost
          ? const [
              PopupMenuItem(
                value: _CardMenuAction.edit,
                child: Text('Edit Session'),
              ),
              PopupMenuItem(
                value: _CardMenuAction.delete,
                child: Text('Delete Session'),
              ),
            ]
          : const [
              PopupMenuItem(
                value: _CardMenuAction.leave,
                child: Text('Leave Session'),
              ),
            ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will permanently delete the session and remove all members. '
                    'This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              loading ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  setDialogState(() => loading = true);
                                  try {
                                    await ref
                                        .read(sessionRepositoryProvider)
                                        .deleteSession(
                                          session.sessionId,
                                          currentUserId,
                                        );
                                    appLogger.info(
                                      'Session deleted from session card',
                                      extra: {'sessionId': session.sessionId},
                                    );
                                    appLogger.debug(
                                      AnalyticsEvents.sessionDeleted,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e, st) {
                                    appLogger.error(
                                      'Delete session failed from session card',
                                      exception: e,
                                      stackTrace: st,
                                      extra: {'sessionId': session.sessionId},
                                    );
                                    setDialogState(() => loading = false);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not delete: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLeaveDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Leave Session?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You will be removed from this session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              loading ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  setDialogState(() => loading = true);
                                  try {
                                    await ref
                                        .read(sessionRepositoryProvider)
                                        .leaveSession(
                                          session.sessionId,
                                          currentUserId,
                                        );
                                    appLogger.info(
                                      'Session left from session card',
                                      extra: {'sessionId': session.sessionId},
                                    );
                                    appLogger.debug(AnalyticsEvents.sessionLeft);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e, st) {
                                    appLogger.error(
                                      'Leave session failed from session card',
                                      exception: e,
                                      stackTrace: st,
                                      extra: {'sessionId': session.sessionId},
                                    );
                                    setDialogState(() => loading = false);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not leave: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Leave'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
