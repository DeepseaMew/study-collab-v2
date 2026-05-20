import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A list tile that renders a single accepted friend.
///
/// Displays [FriendEntity.friendDisplayName] and [FriendEntity.friendPhotoUrl]
/// (via [CachedNetworkImage] with an initials fallback). Exposes an unfriend
/// action via an overflow menu.
class FriendListTile extends StatelessWidget {
  const FriendListTile({
    super.key,
    required this.friend,
    required this.onUnfriend,
  });

  final FriendEntity friend;
  final VoidCallback onUnfriend;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(
        photoUrl: friend.friendPhotoUrl,
        displayName: friend.friendDisplayName,
      ),
      title: Text(
        friend.friendDisplayName.isNotEmpty
            ? friend.friendDisplayName
            : 'Unknown',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: PopupMenuButton<_Action>(
        icon: const Icon(Icons.more_vert, color: AppColors.hint, size: 20),
        onSelected: (action) {
          if (action == _Action.unfriend) {
            onUnfriend();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _Action.unfriend,
            child: Text(
              'Unfriend',
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action { unfriend }

/// Circular avatar that renders [CachedNetworkImage] when [photoUrl] is
/// non-null and non-empty, falling back to an initials circle.
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
          imageBuilder: (_, imageProvider) =>
              CircleAvatar(radius: 20, backgroundImage: imageProvider),
          placeholder: (_, __) => _InitialsAvatar(displayName: displayName),
          errorWidget: (_, __, ___) =>
              _InitialsAvatar(displayName: displayName),
        ),
      );
    }
    return ExcludeSemantics(child: _InitialsAvatar(displayName: displayName));
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
