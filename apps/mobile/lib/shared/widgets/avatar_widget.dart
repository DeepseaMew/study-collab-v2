import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Displays a circular user avatar.
///
/// Rendering priority:
/// 1. [localBytes] — in-memory bytes shown immediately after picking while
///    upload is in progress.
/// 2. [photoUrl] — remote URL loaded via [CachedNetworkImage].
/// 3. Fallback — initials derived from [displayName].
///
/// When [isLoading] is `true` a semi-transparent overlay with a
/// [CircularProgressIndicator] is stacked on top.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 40,
    this.localBytes,
    this.isLoading = false,
  });

  /// Photo URL (remote). Takes priority over initials fallback.
  final String? photoUrl;

  /// Name used to derive the fallback initial and the semantics label.
  final String displayName;

  /// Avatar radius in logical pixels.
  final double radius;

  /// In-memory bytes used as an optimistic local preview while uploading.
  final Uint8List? localBytes;

  /// When `true` an overlay spinner is shown.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avatar of $displayName',
      button: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildBase(),
          if (isLoading)
            CircleAvatar(
              radius: radius,
              backgroundColor: Colors.black38,
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBase() {
    // Priority 1 — local bytes (optimistic preview)
    if (localBytes != null) {
      return ClipOval(
        child: Image.memory(
          localBytes!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    }

    // Priority 2 — remote URL
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => ClipOval(
          child: Image(
            image: imageProvider,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
        placeholder: (_, __) => _InitialsAvatar(
          displayName: displayName,
          radius: radius,
        ),
        errorWidget: (_, __, ___) => _InitialsAvatar(
          displayName: displayName,
          radius: radius,
        ),
      );
    }

    // Priority 3 — initials fallback
    return _InitialsAvatar(displayName: displayName, radius: radius);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.displayName, required this.radius});

  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
