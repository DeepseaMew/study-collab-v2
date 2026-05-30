import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Full join-requests list for a session (host-only).
///
/// Route: `/sessions/:id/requests`
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(joinRequestsProvider(sessionId));
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;

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
          'Join Requests',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: me == null
          ? const Center(
              child: Text(
                'Sign in to view requests.',
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            )
          : requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                appLogger.error(
                  'RequestsScreen failed to load requests',
                  exception: e,
                  stackTrace: st,
                  extra: {'sessionId': sessionId},
                );
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load requests.',
                      style: TextStyle(color: AppColors.hint, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
              data: (requests) {
                if (requests.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.hint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No pending requests.',
                            style: TextStyle(
                              color: AppColors.hint,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _RequestTile(
                    request: requests[i],
                    sessionId: sessionId,
                    callerUid: me.uid,
                  ),
                );
              },
            ),
    );
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

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
        'Request approved from requests screen',
        extra: {'sessionId': widget.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestApproved);
    } catch (e, st) {
      appLogger.error(
        'Approve request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.sessionId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not approve: ${e.toString()}'),
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
        'Request declined from requests screen',
        extra: {'sessionId': widget.sessionId},
      );
      appLogger.debug(AnalyticsEvents.sessionRequestDeclined);
    } catch (e, st) {
      appLogger.error(
        'Decline request failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.sessionId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not decline: ${e.toString()}'),
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
            radius: 22,
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
                      fontSize: 13,
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
                minimumSize: const Size(72, 36),
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
                minimumSize: const Size(72, 36),
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
