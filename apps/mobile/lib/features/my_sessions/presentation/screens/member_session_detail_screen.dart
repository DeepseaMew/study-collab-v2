import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/note_sharing/presentation/widgets/files_tab.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_banner_widget.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_bottom_sheet.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Post-join member view of a session.
///
/// Two tabs: Members and Files (ADR 0008).
/// `ref.listen` on the session stream triggers the rating bottom sheet once
/// when `status` transitions to 'ended'.
///
/// Route: `/my-sessions/session/:id/member`
/// Extra: `{'isCompleted': bool, 'initialTabIndex': int}` (both optional).
class MemberSessionDetailScreen extends ConsumerStatefulWidget {
  const MemberSessionDetailScreen({
    super.key,
    required this.sessionId,
    this.isCompleted = false,
    this.initialTabIndex = 0,
  });

  final String sessionId;
  final bool isCompleted;

  /// Tab index to open on creation. Defaults to 0 (Members).
  /// Pass 1 to open directly at the Files tab.
  final int initialTabIndex;

  @override
  ConsumerState<MemberSessionDetailScreen> createState() =>
      _MemberSessionDetailScreenState();
}

class _MemberSessionDetailScreenState
    extends ConsumerState<MemberSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _sessionEndedPopupShown = false;
  bool _ratingSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _showRatingSheet(
    SessionEntity session,
    List<UserEntity> members,
    String currentUserId,
  ) async {
    if (_ratingSheetOpen) return;
    setState(() => _ratingSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingBottomSheet(
        sessionId: session.sessionId,
        members: members,
        currentUserId: currentUserId,
        hostUid: session.hostUid,
      ),
    );
    if (mounted) setState(() => _ratingSheetOpen = false);
  }

  void _showLeaveDialog(String currentUserId) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Leave Session?',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'You will be removed from this session.',
              style: TextStyle(color: AppColors.hint, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.hint),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
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
                              .leaveSession(widget.sessionId, currentUserId);
                          appLogger.info(
                            'Left session from member detail',
                            extra: {'sessionId': widget.sessionId},
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) context.pop();
                        } catch (e, st) {
                          appLogger.error(
                            'Leave session failed from member detail',
                            exception: e,
                            stackTrace: st,
                            extra: {'sessionId': widget.sessionId},
                          );
                          setDialogState(() => loading = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider(widget.sessionId));
    final membersAsync = ref.watch(sessionMembersProvider(widget.sessionId));
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;

    ref.listen<AsyncValue<SessionEntity?>>(
      sessionStreamProvider(widget.sessionId),
      (prev, next) {
        final session = next.asData?.value;
        if (session == null || session.status != 'ended' || _sessionEndedPopupShown) return;

        // Guard: members must be loaded before opening the sheet.
        final members = ref.read(sessionMembersProvider(widget.sessionId)).asData?.value ?? [];
        if (members.isEmpty) return;

        final currentUid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
        if (currentUid.isEmpty) return;

        // Guard: skip if already rated (e.g. rated on another device).
        final hasRated = ref.read(hasRatedProvider(widget.sessionId, currentUid)).valueOrNull;
        if (hasRated == true) return;

        setState(() => _sessionEndedPopupShown = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRatingSheet(session, members, currentUid);
        });
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7143BF), AppColors.accent],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Session Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: widget.isCompleted
            ? null
            : [
                // SEC-010: Only render the leave menu when me is non-null so
                // that _showLeaveDialog is never called with an empty-string uid.
                if (me != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (action) {
                      if (action == 'leave') _showLeaveDialog(me.uid);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'leave',
                        child: Text('Leave Session'),
                      ),
                    ],
                  ),
              ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          appLogger.error(
            'MemberSessionDetailScreen failed to load',
            exception: e,
            stackTrace: st,
            extra: {'sessionId': widget.sessionId},
          );
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load session. Please try again.',
                style: TextStyle(color: AppColors.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (session) {
          if (session == null) {
            return const Center(
              child: Text(
                'Session not found.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            );
          }
          final members = membersAsync.asData?.value ?? [];

          return Column(
            children: [
              _SessionInfoCard(
                session: session,
                badge: session.hostUid == me?.uid ? 'Hosting' : 'Joined',
                badgeColor: session.hostUid == me?.uid
                    ? AppColors.accent
                    : AppColors.success,
                showCheckIcon: true,
              ),
              RatingBannerWidget(
                sessionId: widget.sessionId,
                currentUserId: me?.uid ?? '',
                members: members,
                hostUid: session.hostUid,
                sessionStatus: session.status,
              ),
              TabBar(
                controller: _tab,
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
                  Tab(text: 'Members'),
                  Tab(text: 'Files'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _MembersTab(
                      session: session,
                      members: members,
                      currentUserId: me?.uid ?? '',
                      isCompleted: widget.isCompleted,
                    ),
                    FilesTab(
                      sessionId: widget.sessionId,
                      currentUserId: me?.uid ?? '',
                      hostUid: session.hostUid,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Session info card ──────────────────────────────────────────────────────────

class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({
    required this.session,
    required this.badge,
    required this.badgeColor,
    this.showCheckIcon = false,
  });

  final SessionEntity session;
  final String badge;
  final Color badgeColor;
  final bool showCheckIcon;

  @override
  Widget build(BuildContext context) {
    final progress = session.capacity > 0
        ? (session.participantCount / session.capacity).clamp(0.0, 1.0)
        : 0.0;
    final subjectLabel = session.hashtags.isNotEmpty
        ? session.hashtags.first
        : session.academicLevel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCheckIcon) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Avatar(
                displayName: session.hostDisplayName,
                photoUrl: session.hostPhotoUrl,
                radius: 12,
              ),
              const SizedBox(width: 6),
              Text(
                'Hosted by ${session.hostDisplayName}',
                style: const TextStyle(color: AppColors.hint, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.hint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.scheduledEndAt != null
                      ? '${DateFormatter.relativeDate(session.scheduledAt)}  '
                            '${DateFormatter.timeRange(session.scheduledAt, session.scheduledEndAt!)}'
                      : DateFormatter.relativeDate(session.scheduledAt),
                  style: const TextStyle(color: AppColors.hint, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.hint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.location,
                  style: const TextStyle(color: AppColors.hint, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 14, color: AppColors.hint),
              const SizedBox(width: 6),
              Text(
                '${session.participantCount}/${session.capacity} members',
                style: const TextStyle(color: AppColors.hint, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: AppColors.accent,
              backgroundColor: AppColors.secondary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Members ─────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.session,
    required this.members,
    required this.currentUserId,
    required this.isCompleted,
  });

  final SessionEntity session;
  final List<UserEntity> members;
  final String currentUserId;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final hostMember = members
        .where((m) => m.uid == session.hostUid)
        .firstOrNull;
    final nonHostMembers = members
        .where((m) => m.uid != session.hostUid)
        .toList();
    final previewMembers = nonHostMembers.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Host',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _HostRow(
            displayName: hostMember?.displayName ?? session.hostDisplayName,
            photoUrl: hostMember?.photoUrl ?? session.hostPhotoUrl,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${nonHostMembers.length + 1})',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  RouteConstants.sessionMembers.replaceFirst(
                    ':id',
                    session.sessionId,
                  ),
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(color: AppColors.accent, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (nonHostMembers.isEmpty)
            const Text(
              'No members yet.',
              style: TextStyle(color: AppColors.hint, fontSize: 13),
            )
          else
            Row(
              children: previewMembers
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Avatar(
                        displayName: m.displayName,
                        photoUrl: m.photoUrl,
                        radius: 20,
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (!isCompleted) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message group'),
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _HostRow extends StatelessWidget {
  const _HostRow({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(displayName: displayName, photoUrl: photoUrl, radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            displayName,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }
}

// ── Tab 1: Files is now FilesTab (ADR 0008) ────────────────────────────────────

// ── Avatar helper ──────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
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
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
