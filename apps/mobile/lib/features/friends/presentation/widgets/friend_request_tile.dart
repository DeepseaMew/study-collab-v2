import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A list tile that renders a single incoming or outgoing friend request.
///
/// For incoming requests, exposes accept and decline action buttons.
/// For outgoing requests, exposes a withdraw action button.
class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.request,
    required this.isIncoming,
    this.onAccept,
    this.onDecline,
    this.onWithdraw,
  });

  final FriendEntity request;

  /// `true` → tile shows Accept + Decline. `false` → tile shows Withdraw.
  final bool isIncoming;

  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(
        photoUrl: request.friendPhotoUrl,
        displayName: request.friendDisplayName,
      ),
      title: Text(
        request.friendDisplayName.isNotEmpty
            ? request.friendDisplayName
            : request.friendUid,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        isIncoming ? 'Sent you a friend request' : 'Request pending',
        style: const TextStyle(color: AppColors.hint, fontSize: 12),
      ),
      trailing: isIncoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  label: 'Accept',
                  isPrimary: true,
                  onPressed: onAccept,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Decline',
                  isPrimary: false,
                  onPressed: onDecline,
                ),
              ],
            )
          : _ActionButton(
              label: 'Withdraw',
              isPrimary: false,
              onPressed: onWithdraw,
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: isPrimary
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.hint,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.displayName});

  final String? photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return ExcludeSemantics(
        child: CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (_, imageProvider) => CircleAvatar(
            radius: 20,
            backgroundImage: imageProvider,
          ),
          placeholder: (_, __) => _InitialsAvatar(displayName: displayName),
          errorWidget: (_, __, ___) =>
              _InitialsAvatar(displayName: displayName),
        ),
      );
    }
    return ExcludeSemantics(
      child: _InitialsAvatar(displayName: displayName),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.displayName});

  final String displayName;

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || displayName.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.secondary,
      child: Text(
        _initials,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
