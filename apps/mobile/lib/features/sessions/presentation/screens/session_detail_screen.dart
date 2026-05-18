import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Public pre-join session detail screen.
///
/// Accessible from Search and Home. Shows session info, members preview,
/// and a context-aware join action row.
///
/// Route: `/sessions/:id`
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStreamProvider(sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) {
        appLogger.error(
          'SessionDetailScreen failed to load',
          exception: e,
          stackTrace: st,
          extra: {'sessionId': sessionId},
        );
        return _SessionNotFoundScaffold(message: e.toString());
      },
      data: (session) {
        if (session == null) {
          return const _SessionNotFoundScaffold(
            message: 'This session no longer exists.',
          );
        }
        return _SessionDetailBody(session: session);
      },
    );
  }
}

// ── Not-found scaffold ────────────────────────────────────────────────────────

class _SessionNotFoundScaffold extends StatelessWidget {
  const _SessionNotFoundScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Session'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.hint),
              const SizedBox(height: 16),
              const Text(
                'Session not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

enum _HostAction { edit, delete, copyLink }

class _SessionDetailBody extends ConsumerWidget {
  const _SessionDetailBody({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(sessionMembersProvider(session.sessionId));
    final meAsync = ref.watch(currentUserProvider);
    final me = meAsync.asData?.value;
    final isHost = me != null && me.uid == session.hostUid;

    final members = membersAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Pinned app bar ───────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.text,
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              session.title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isHost)
                PopupMenuButton<_HostAction>(
                  icon: const Icon(Icons.more_vert, color: AppColors.text),
                  onSelected: (action) async {
                    // me is non-null here because isHost guarantees it.
                    switch (action) {
                      case _HostAction.edit:
                        unawaited(
                          context.push(
                            RouteConstants.sessionEdit
                                .replaceFirst(':id', session.sessionId),
                          ),
                        );
                      case _HostAction.delete:
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Session?'),
                            content: const Text(
                              'This will permanently remove the session and all its data. '
                              'Members will be notified.',
                            ),
                            actions: [
                              OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFE53E3E),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await ref
                                .read(sessionRepositoryProvider)
                                .deleteSession(session.sessionId, me.uid);
                            appLogger.info(
                              'Session deleted from detail screen',
                              extra: {'sessionId': session.sessionId},
                            );
                            appLogger.debug(AnalyticsEvents.sessionDeleted);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Session deleted'),
                                ),
                              );
                              context.pop();
                            }
                          } catch (e, st) {
                            appLogger.error(
                              'Delete session failed from detail',
                              exception: e,
                              stackTrace: st,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        }
                      case _HostAction.copyLink:
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                'studycollab://session/${session.sessionId}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied!')),
                          );
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _HostAction.edit,
                      child: Text('Edit Session'),
                    ),
                    PopupMenuItem(
                      value: _HostAction.delete,
                      child: Text('Delete Session'),
                    ),
                    PopupMenuItem(
                      value: _HostAction.copyLink,
                      child: Text('Copy Invite Link'),
                    ),
                  ],
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _InfoChipsRow(session: session),
                  const SizedBox(height: 16),
                  Text(
                    session.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HostRow(session: session),
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormatter.relativeDate(session.scheduledAt),
                    sub: session.scheduledEndAt != null
                        ? DateFormatter.timeRange(
                            session.scheduledAt,
                            session.scheduledEndAt!,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _InfoCard(
                    icon: Icons.location_on_outlined,
                    label: session.location,
                  ),
                  const SizedBox(height: 8),
                  _InfoCard(
                    icon: Icons.group_outlined,
                    label:
                        '${session.participantCount} / ${session.capacity} members',
                    sub: session.isFull
                        ? 'Full'
                        : '${session.spotsLeft} spots left',
                  ),
                  const SizedBox(height: 16),
                  if ((session.description ?? '').isNotEmpty) ...[
                    const Text(
                      'About this session',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.description!,
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (session.hashtags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: session.hashtags
                          .map((tag) => _HashtagChip(tag: tag))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CapacityBar(session: session),
                  const SizedBox(height: 24),

                  // ── Members section ───────────────────────────────────────
                  _SectionHeader(
                    title: 'Members',
                    trailingLabel: members.length > 3 ? 'See All' : null,
                    onTrailingTap: members.length > 3
                        ? () => context.push(
                              RouteConstants.sessionMembers
                                  .replaceFirst(':id', session.sessionId),
                            )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  membersAsync.when(
                    loading: () => const _LoadingRow(),
                    error: (_, __) =>
                        const _ErrorRow(message: 'Could not load members'),
                    data: (list) => _MembersPreviewRow(
                      members: list.take(5).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Pending requests (host-only) ──────────────────────────
                  if (isHost) ...[
                    _HostRequestsSection(
                      session: session,
                      callerUid: me.uid,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Join action row ───────────────────────────────────────
                  _JoinActionRow(session: session, me: me),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chips row ────────────────────────────────────────────────────────────

class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context) {
    final subjectLabel =
        session.hashtags.isNotEmpty ? session.hashtags.first : session.academicLevel;
    final visibilityLabel =
        session.visibility == 'private' ? 'Private' : 'Public';

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            subjectLabel,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            visibilityLabel,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Host row ──────────────────────────────────────────────────────────────────

class _HostRow extends StatelessWidget {
  const _HostRow({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context) {
    final initial = session.hostDisplayName.isNotEmpty
        ? session.hostDisplayName[0].toUpperCase()
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
          backgroundImage: session.hostPhotoUrl != null &&
                  session.hostPhotoUrl!.isNotEmpty
              ? CachedNetworkImageProvider(session.hostPhotoUrl!)
              : null,
          child: session.hostPhotoUrl == null || session.hostPhotoUrl!.isEmpty
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
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hosted by',
              style: TextStyle(color: AppColors.hint, fontSize: 11),
            ),
            Text(
              session.hostDisplayName,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
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

// ── Hashtag chip ──────────────────────────────────────────────────────────────

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Capacity bar ──────────────────────────────────────────────────────────────

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context) {
    final progress = session.capacity > 0
        ? (session.participantCount / session.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            color: AppColors.accent,
            backgroundColor: AppColors.secondary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.spotsLeft} / ${session.capacity} spots remaining',
          style: const TextStyle(color: AppColors.hint, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailingLabel != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Members preview row ───────────────────────────────────────────────────────

class _MembersPreviewRow extends StatelessWidget {
  const _MembersPreviewRow({required this.members});

  final List<UserEntity> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text(
        'No members yet.',
        style: TextStyle(color: AppColors.hint, fontSize: 13),
      );
    }
    return Row(
      children: members
          .map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: m.displayName,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.secondary,
                  backgroundImage: m.photoUrl != null && m.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(m.photoUrl!)
                      : null,
                  child: m.photoUrl == null || m.photoUrl!.isEmpty
                      ? Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Request tile (compact, inline, up to 3) ───────────────────────────────────

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({
    required this.request,
    required this.session,
    required this.callerUid,
  });

  final JoinRequestEntity request;
  final SessionEntity session;
  final String callerUid;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _approvingLoading = false;
  bool _decliningLoading = false;

  Future<void> _approve() async {
    setState(() => _approvingLoading = true);
    try {
      await ref.read(joinRequestRepositoryProvider).approveRequest(
            widget.session.sessionId,
            widget.callerUid,
            widget.request.uid,
          );
      appLogger.info(
        'Request approved',
        extra: {'sessionId': widget.session.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestApproved);
    } catch (e, st) {
      appLogger.error(
        'Approve request failed',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not approve request: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _approvingLoading = false);
    }
  }

  Future<void> _decline() async {
    if (widget.callerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    setState(() => _decliningLoading = true);
    try {
      await ref.read(joinRequestRepositoryProvider).declineRequest(
            widget.session.sessionId,
            widget.callerUid,
            widget.request.uid,
          );
      appLogger.info(
        'Request declined',
        extra: {'sessionId': widget.session.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestDeclined);
    } catch (e, st) {
      appLogger.error(
        'Decline request failed',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not decline request: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _decliningLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.request.displayName.isNotEmpty
        ? widget.request.displayName[0].toUpperCase()
        : '?';
    final isWorking = _approvingLoading || _decliningLoading;

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
            radius: 18,
            backgroundColor: AppColors.secondary,
            backgroundImage: widget.request.photoUrl != null &&
                    widget.request.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.request.photoUrl!)
                : null,
            child: widget.request.photoUrl == null ||
                    widget.request.photoUrl!.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.displayName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormatter.relative(widget.request.requestedAt),
                  style: const TextStyle(color: AppColors.hint, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                minimumSize: const Size(70, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isWorking ? null : _decline,
              child: _decliningLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Text('Decline', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(70, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isWorking ? null : _approve,
              child: _approvingLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Approve',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Host requests section (host-only widget — subscribes joinRequestsProvider) ─

class _HostRequestsSection extends ConsumerWidget {
  const _HostRequestsSection({
    required this.session,
    required this.callerUid,
  });

  final SessionEntity session;
  final String callerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(joinRequestsProvider(session.sessionId));
    final requests = requestsAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Requests',
          trailingLabel: requests.length > 3 ? 'See All' : null,
          onTrailingTap: requests.length > 3
              ? () => context.push(
                    RouteConstants.sessionRequests
                        .replaceFirst(':id', session.sessionId),
                  )
              : null,
        ),
        const SizedBox(height: 8),
        requestsAsync.when(
          loading: () => const _LoadingRow(),
          error: (_, __) =>
              const _ErrorRow(message: 'Could not load requests'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No pending requests.',
                  style: TextStyle(color: AppColors.hint, fontSize: 13),
                ),
              );
            }
            return Column(
              children: list
                  .take(3)
                  .map(
                    (req) => _RequestTile(
                      request: req,
                      session: session,
                      callerUid: callerUid,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Join action row ───────────────────────────────────────────────────────────

class _JoinActionRow extends ConsumerWidget {
  const _JoinActionRow({required this.session, required this.me});

  final SessionEntity session;
  final UserEntity? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me == null) {
      return _NotJoinedActions(session: session, me: me);
    }
    if (session.hostUid == me!.uid) {
      // Host — show message group button.
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.hint,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: () {
          // Chat screen not yet implemented; placeholder.
        },
        icon: const Icon(Icons.message_outlined, size: 18),
        label: const Text('Message Group'),
      );
    }
    if (session.memberUids.contains(me!.uid)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Joined',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Check pending via single-document watch (requester reads own doc only).
    final isPending =
        ref.watch(myPendingRequestProvider(session.sessionId, me!.uid)).asData?.value ?? false;

    if (isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Pending...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _NotJoinedActions(session: session, me: me);
  }
}

class _NotJoinedActions extends ConsumerStatefulWidget {
  const _NotJoinedActions({required this.session, required this.me});

  final SessionEntity session;
  final UserEntity? me;

  @override
  ConsumerState<_NotJoinedActions> createState() => _NotJoinedActionsState();
}

class _NotJoinedActionsState extends ConsumerState<_NotJoinedActions> {
  bool _loading = false;

  Future<void> _requestJoin() async {
    final me = widget.me;
    if (me == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(joinRequestRepositoryProvider).submitRequest(
            widget.session.sessionId,
            JoinRequestEntity(
              uid: me.uid,
              displayName: me.displayName,
              photoUrl: me.photoUrl,
              requestedAt: DateTime.now(),
            ),
          );
      appLogger.info(
        'Join request submitted',
        extra: {'sessionId': widget.session.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionJoinRequested);
    } catch (e, st) {
      appLogger.error('Request join failed', exception: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinWithPassword() async {
    final me = widget.me;
    if (me == null) return;

    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinPasswordDialog(),
    );
    if (password == null || password.isEmpty) return;

    setState(() => _loading = true);
    try {
      final request = JoinRequestEntity(
        uid: me.uid,
        displayName: me.displayName,
        photoUrl: me.photoUrl,
        requestedAt: DateTime.now(),
      );
      await ref.read(joinRequestRepositoryProvider).joinWithPin(
            widget.session.sessionId,
            request,
            password,
          );
      appLogger.info(
        'Joined private session with PIN',
        extra: {'sessionId': widget.session.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionJoined);
    } catch (e, st) {
      appLogger.error('Join with password failed', exception: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.visibility == 'private') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: _loading ? null : _joinWithPassword,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_outline, size: 16),
        label: const Text('Join with Password'),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        minimumSize: const Size(double.infinity, 48),
      ),
      onPressed: _loading ? null : _requestJoin,
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Request to Join'),
    );
  }
}

// ── Join password dialog ──────────────────────────────────────────────────────

class _JoinPasswordDialog extends StatefulWidget {
  const _JoinPasswordDialog();

  @override
  State<_JoinPasswordDialog> createState() => _JoinPasswordDialogState();
}

class _JoinPasswordDialogState extends State<_JoinPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Enter Session Password',
        style: TextStyle(color: AppColors.text, fontSize: 16),
      ),
      content: TextField(
        controller: _ctrl,
        obscureText: _obscure,
        decoration: InputDecoration(
          hintText: 'Password',
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: AppColors.hint,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.hint)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

// ── Loading / error inline placeholders ──────────────────────────────────────

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.hint, fontSize: 13),
      ),
    );
  }
}
