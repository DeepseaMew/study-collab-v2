import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/friends/domain/entities/friendship_status.dart';
import 'package:mobile/features/friends/presentation/providers/friend_action_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A stateful button that adapts its label and action to the current
/// [FriendshipStatus] between the viewer and the profile owner.
///
/// This widget is consumed by profile screens (own profile and others').
///
/// Import [FriendshipStatus] from:
///   `package:mobile/features/friends/domain/entities/friendship_status.dart`
class AddFriendButton extends ConsumerWidget {
  const AddFriendButton({
    super.key,
    required this.status,
    required this.currentUid,
    required this.targetUid,
  });

  /// The current relationship between [currentUid] and [targetUid].
  final FriendshipStatus status;

  /// UID of the signed-in viewer.
  final String currentUid;

  /// UID of the profile owner being viewed.
  final String targetUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status == FriendshipStatus.self) return const SizedBox.shrink();

    final actionState = ref.watch(friendActionNotifierProvider);
    final isLoading = actionState.isLoading;

    return switch (status) {
      FriendshipStatus.notFriends => _PrimaryButton(
        label: 'Add Friend',
        isLoading: isLoading,
        onPressed: isLoading ? null : () => _sendRequest(ref, context),
      ),
      FriendshipStatus.requestSent => Semantics(
        label: 'Friend request sent, tap to withdraw',
        button: true,
        child: _OutlinedActionButton(
          label: 'Pending',
          isLoading: isLoading,
          onPressed: isLoading ? null : () => _withdrawRequest(ref, context),
        ),
      ),
      FriendshipStatus.requestReceived => _PrimaryButton(
        label: 'Accept',
        isLoading: isLoading,
        onPressed: isLoading ? null : () => _acceptRequest(ref, context),
      ),
      FriendshipStatus.friends => _OutlinedActionButton(
        label: 'Friends',
        isLoading: isLoading,
        onPressed: isLoading ? null : () => _confirmUnfriend(ref, context),
      ),
      FriendshipStatus.self => const SizedBox.shrink(),
    };
  }

  Future<void> _sendRequest(WidgetRef ref, BuildContext context) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .sendRequest(currentUid: currentUid, targetUid: targetUid);
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  Future<void> _withdrawRequest(WidgetRef ref, BuildContext context) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .withdrawRequest(currentUid: currentUid, targetUid: targetUid);
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  Future<void> _acceptRequest(WidgetRef ref, BuildContext context) async {
    await ref
        .read(friendActionNotifierProvider.notifier)
        .acceptRequest(currentUid: currentUid, initiatorUid: targetUid);
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  Future<void> _confirmUnfriend(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfriend'),
        content: const Text('Remove this person from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Unfriend',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref
        .read(friendActionNotifierProvider.notifier)
        .unfriend(currentUid: currentUid, friendUid: targetUid);
    if (!context.mounted) return;
    _handleError(ref, context);
  }

  void _handleError(WidgetRef ref, BuildContext context) {
    final state = ref.read(friendActionNotifierProvider);
    if (state.hasError && context.mounted) {
      appLogger.error('AddFriendButton action error', exception: state.error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          : Text(label),
    );
  }
}
