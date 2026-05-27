import 'package:flutter/material.dart';

/// Displays a user's profile score (percentage of thumbs-up ratings).
///
/// Shows a "No ratings yet" state when [profileScore] is 0.0.
class ProfileScoreWidget extends StatelessWidget {
  const ProfileScoreWidget({
    super.key,
    required this.profileScore,
    required this.completedSessionCount,
  });

  final double profileScore;
  final int completedSessionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (profileScore == 0.0) {
      return Semantics(
        label: 'No ratings yet',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.thumb_up_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 2),
            Text(
              'No ratings yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final pct = (profileScore * 100).toStringAsFixed(0);
    return Semantics(
      label: '$pct percent positive rating',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thumb_up, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 2),
          Text(
            '$pct%',
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            'from $completedSessionCount sessions',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
