import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friend_action_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/providers/outgoing_requests_provider.dart';
import 'package:mobile/features/friends/presentation/widgets/friend_request_tile.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Full incoming and outgoing friend-request list screen.
///
/// Navigated to from the Friends screen when the user taps the requests badge
/// or tab. Shows two sections: incoming requests and outgoing requests.
///
/// Route: `/friends/requests`
class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key, required this.currentUid});

  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingRequestsProvider(currentUid));
    final outgoingAsync = ref.watch(outgoingRequestsProvider(currentUid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Incoming'),
          incomingAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, st) {
              appLogger.error(
                'FriendRequestsScreen incoming error',
                exception: e,
                stackTrace: st,
              );
              return const _ErrorTile(message: 'Could not load requests.');
            },
            data: (requests) => requests.isEmpty
                ? const _EmptyTile(message: 'No incoming requests.')
                : Column(
                    children: requests
                        .map(
                          (r) => FriendRequestTile(
                            request: r,
                            isIncoming: true,
                            onAccept: () => _accept(ref, context, r),
                            onDecline: () => _decline(ref, context, r),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const Divider(thickness: 1, color: AppColors.border),
          const _SectionHeader(title: 'Sent'),
          outgoingAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, st) {
              appLogger.error(
                'FriendRequestsScreen outgoing error',
                exception: e,
                stackTrace: st,
              );
              return const _ErrorTile(message: 'Could not load sent requests.');
            },
            data: (requests) => requests.isEmpty
                ? const _EmptyTile(message: 'No sent requests.')
                : Column(
                    children: requests
                        .map(
                          (r) => FriendRequestTile(
                            request: r,
                            isIncoming: false,
                            onWithdraw: () => _withdraw(ref, context, r),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(
    WidgetRef ref,
    BuildContext context,
    FriendEntity request,
  ) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .acceptRequest(
          currentUid: currentUid,
          initiatorUid: request.friendUid,
        );
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  Future<void> _decline(
    WidgetRef ref,
    BuildContext context,
    FriendEntity request,
  ) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .declineRequest(
          currentUid: currentUid,
          initiatorUid: request.friendUid,
        );
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  Future<void> _withdraw(
    WidgetRef ref,
    BuildContext context,
    FriendEntity request,
  ) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .withdrawRequest(
          currentUid: currentUid,
          targetUid: request.friendUid,
        );
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  void _handleError(WidgetRef ref, BuildContext context) {
    final state = ref.read(friendActionNotifierProvider);
    if (state.hasError && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.hint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.hint, fontSize: 14),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 14),
      ),
    );
  }
}
