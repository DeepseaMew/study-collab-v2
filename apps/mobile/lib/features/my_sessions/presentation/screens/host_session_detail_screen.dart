import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

enum _HostAction { edit, delete }

/// Host management view of a session.
///
/// Three tabs: Members (with End Session), Notes (placeholder), Requests.
///
/// Route: `/my-sessions/session/:id/host`
class HostSessionDetailScreen extends ConsumerStatefulWidget {
  const HostSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<HostSessionDetailScreen> createState() =>
      _HostSessionDetailScreenState();
}

class _HostSessionDetailScreenState
    extends ConsumerState<HostSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showEndSessionSheet(
    SessionEntity session,
    List<UserEntity> members,
    String hostUid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _EndSessionSheet(
        session: session,
        members: members,
        currentUserId: hostUid,
      ),
    );
  }

  void _onMenuAction(
    _HostAction action,
    SessionEntity session,
    String hostUid,
  ) {
    switch (action) {
      case _HostAction.edit:
        context.push(
          RouteConstants.sessionEdit.replaceFirst(':id', session.sessionId),
        );
      case _HostAction.delete:
        _showDeleteDialog(session, hostUid);
    }
  }

  void _showDeleteDialog(SessionEntity session, String hostUid) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete Session?'),
            content: const Text(
              'This will permanently remove the session and all its data. '
              'Members will be notified.',
            ),
            actions: [
              OutlinedButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                ),
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        try {
                          await ref
                              .read(sessionRepositoryProvider)
                              .deleteSession(session.sessionId, hostUid);
                          appLogger.info(
                            'Session deleted from host detail screen',
                            extra: {'sessionId': session.sessionId},
                          );
                          appLogger.debug(AnalyticsEvents.sessionDeleted);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Session deleted')),
                            );
                            context.pop();
                          }
                        } catch (e, st) {
                          appLogger.error(
                            'Delete session failed from host detail screen',
                            exception: e,
                            stackTrace: st,
                            extra: {'sessionId': session.sessionId},
                          );
                          setDialogState(() => loading = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
    final requestsAsync = ref.watch(joinRequestsProvider(widget.sessionId));
    final me = ref.watch(currentUserProvider).asData?.value;

    final session = sessionAsync.asData?.value;

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
        actions: [
          if (session != null && me != null)
            PopupMenuButton<_HostAction>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (action) => _onMenuAction(action, session, me.uid),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _HostAction.edit,
                  child: Text('Edit Session'),
                ),
                PopupMenuItem(
                  value: _HostAction.delete,
                  child: Text('Delete Session'),
                ),
              ],
            ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          appLogger.error(
            'HostSessionDetailScreen failed to load',
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
          final requests = requestsAsync.asData?.value ?? [];
          return Column(
            children: [
              _SessionInfoCard(session: session, currentUserId: me?.uid ?? ''),
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
                  Tab(text: 'Notes'),
                  Tab(text: 'Requests'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _MembersTab(
                      session: session,
                      members: members,
                      onEndSession: me == null
                          ? null
                          : () =>
                                _showEndSessionSheet(session, members, me.uid),
                    ),
                    const _NotesTab(),
                    _RequestsTab(
                      session: session,
                      requests: requests,
                      callerUid: me?.uid ?? '',
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

class _SessionInfoCard extends ConsumerStatefulWidget {
  const _SessionInfoCard({required this.session, required this.currentUserId});

  final SessionEntity session;
  final String currentUserId;

  @override
  ConsumerState<_SessionInfoCard> createState() => _SessionInfoCardState();
}

class _SessionInfoCardState extends ConsumerState<_SessionInfoCard> {
  // PIN reveal state — lazy fetch on first eye-icon tap.
  bool _pinRevealed = false;
  bool _pinLoading = false;
  String? _fetchedPin;
  String? _pinError;

  Future<void> _togglePin() async {
    if (_pinRevealed) {
      // Hide the PIN again (no network call needed).
      setState(() => _pinRevealed = false);
      return;
    }

    // Reveal: fetch lazily if not yet fetched.
    if (_fetchedPin != null) {
      setState(() => _pinRevealed = true);
      return;
    }

    setState(() {
      _pinLoading = true;
      _pinError = null;
    });
    try {
      final pin = await ref
          .read(sessionRepositoryProvider)
          .fetchPin(widget.session.sessionId, widget.currentUserId);
      if (mounted) {
        setState(() {
          _fetchedPin = pin;
          _pinRevealed = true;
          _pinLoading = false;
        });
      }
    } catch (e, st) {
      appLogger.error(
        'fetchPin failed in host detail screen',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.session.sessionId},
      );
      if (mounted) {
        setState(() {
          _pinError = 'Could not load PIN';
          _pinLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Hosting',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
          // ── PIN row — private sessions only ──────────────────────────
          if (session.visibility == 'private') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.hint),
                const SizedBox(width: 6),
                const Text(
                  'PIN',
                  style: TextStyle(
                    color: AppColors.hint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (_pinLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else if (_pinError != null)
                  Text(
                    _pinError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    _pinRevealed ? (_fetchedPin ?? '------') : '••••••',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      letterSpacing: _pinRevealed ? 2.0 : 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (!_pinLoading)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _pinRevealed
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.hint,
                    ),
                    onPressed: _togglePin,
                  ),
              ],
            ),
          ],
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

// ── Tab 0: Members ─────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.session,
    required this.members,
    required this.onEndSession,
  });

  final SessionEntity session;
  final List<UserEntity> members;
  final VoidCallback? onEndSession;

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
          const SizedBox(height: 24),
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
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onEndSession,
            child: const Text('End Session'),
          ),
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

// ── Tab 1: Notes placeholder ───────────────────────────────────────────────────

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: const Icon(
                Icons.search_outlined,
                color: AppColors.hint,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: AppColors.secondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notes uploaded yet',
                    style: TextStyle(color: AppColors.hint, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Upload Note'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Requests ────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.session,
    required this.requests,
    required this.callerUid,
  });

  final SessionEntity session;
  final List<JoinRequestEntity> requests;
  final String callerUid;

  @override
  Widget build(BuildContext context) {
    // +1 for the header row; +1 for either the empty state or the first tile.
    final itemCount = requests.isEmpty ? 2 : 1 + requests.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text(
                  'Pending requests',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (requests.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppColors.secondary,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No pending requests',
                    style: TextStyle(color: AppColors.hint, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        final req = requests[i - 1];
        return _RequestTile(
          request: req,
          sessionId: session.sessionId,
          callerUid: callerUid,
        );
      },
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({
    required this.request,
    required this.sessionId,
    required this.callerUid,
  });

  final JoinRequestEntity request;
  final String sessionId;
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
      await ref
          .read(joinRequestRepositoryProvider)
          .approveRequest(
            widget.sessionId,
            widget.callerUid,
            widget.request.uid,
          );
      appLogger.info(
        'Request approved from host detail screen',
        extra: {'sessionId': widget.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestApproved);
    } catch (e, st) {
      appLogger.error(
        'Approve request failed in host detail screen',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.sessionId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not approve: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _approvingLoading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _decliningLoading = true);
    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .declineRequest(
            widget.sessionId,
            widget.callerUid,
            widget.request.uid,
          );
      appLogger.info(
        'Request declined from host detail screen',
        extra: {'sessionId': widget.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestDeclined);
    } catch (e, st) {
      appLogger.error(
        'Decline request failed in host detail screen',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.sessionId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not decline: $e'),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.secondary,
            backgroundImage:
                widget.request.photoUrl != null &&
                    widget.request.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.request.photoUrl!)
                : null,
            child:
                widget.request.photoUrl == null ||
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
            height: 36,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                minimumSize: const Size(70, 36),
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
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(70, 36),
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
                  : const Text('Approve', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── End Session bottom sheet ───────────────────────────────────────────────────

class _EndSessionSheet extends ConsumerStatefulWidget {
  const _EndSessionSheet({
    required this.session,
    required this.members,
    required this.currentUserId,
  });

  final SessionEntity session;
  final List<UserEntity> members;
  final String currentUserId;

  @override
  ConsumerState<_EndSessionSheet> createState() => _EndSessionSheetState();
}

class _EndSessionSheetState extends ConsumerState<_EndSessionSheet> {
  final Map<String, bool> _thumbsUp = {};
  String _searchQuery = '';
  bool _submitting = false;

  List<UserEntity> get _sorted {
    final host = widget.members
        .where((m) => m.uid == widget.session.hostUid)
        .toList();
    final self = widget.members
        .where(
          (m) =>
              m.uid == widget.currentUserId && m.uid != widget.session.hostUid,
        )
        .toList();
    final others = widget.members
        .where(
          (m) =>
              m.uid != widget.session.hostUid && m.uid != widget.currentUserId,
        )
        .toList();
    return [...host, ...self, ...others];
  }

  List<UserEntity> get _filtered {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _sorted;
    return _sorted
        .where((m) => m.displayName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .endSession(widget.session.sessionId, widget.currentUserId);
      appLogger.info(
        'Session ended from host detail screen',
        extra: {'sessionId': widget.session.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionEnded);
      final thumbsUpCount = _thumbsUp.values.where((v) => v).length;
      appLogger.info(
        'Host rating submitted',
        extra: {'thumbsUpCount': thumbsUpCount},
      );
      appLogger.debug(AnalyticsEvents.sessionRatingSubmitted);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended & ratings submitted!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e, st) {
      appLogger.error(
        'End session failed from host detail screen',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.session.sessionId},
      );
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not end session: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SESSION ENDED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.hint),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.session.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.scheduledEndAt != null
                    ? '${DateFormatter.relativeDate(widget.session.scheduledAt)} · '
                          '${DateFormatter.timeRange(widget.session.scheduledAt, widget.session.scheduledEndAt!)}'
                    : DateFormatter.relativeDate(widget.session.scheduledAt),
                style: const TextStyle(color: AppColors.hint, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Anyone stand out?',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'There were ${widget.members.length} people in this room. '
                  "Give a quick thumbs up to anyone you'd like to study with again.",
                  style: const TextStyle(color: AppColors.hint, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search participants by name',
                  prefixIcon: const Icon(
                    Icons.search_outlined,
                    color: AppColors.hint,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No participants found.',
                          style: TextStyle(color: AppColors.hint, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final m = filtered[i];
                          final isHost = m.uid == widget.session.hostUid;
                          final isSelf = m.uid == widget.currentUserId;
                          if (isHost) {
                            return _BadgeTile(
                              member: m,
                              badge: 'Host',
                              badgeColor: AppColors.accent,
                            );
                          }
                          if (isSelf) {
                            return _BadgeTile(
                              member: m,
                              badge: 'ME',
                              badgeColor: AppColors.hint,
                            );
                          }
                          final liked = _thumbsUp[m.uid] ?? false;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _Avatar(
                              displayName: m.displayName,
                              photoUrl: m.photoUrl,
                              radius: 20,
                            ),
                            title: Text(
                              m.displayName,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                liked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                color: liked
                                    ? AppColors.accent
                                    : AppColors.hint,
                              ),
                              onPressed: () =>
                                  setState(() => _thumbsUp[m.uid] = !liked),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge tile (Host / ME — no thumbs-up toggle) ───────────────────────────────

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.member,
    required this.badge,
    required this.badgeColor,
  });

  final UserEntity member;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Avatar(
        displayName: member.displayName,
        photoUrl: member.photoUrl,
        radius: 20,
      ),
      title: Text(
        member.displayName,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          badge,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

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
