import 'package:flutter/material.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Renders a single hashtag string as a Material [Chip].
///
/// Stateless. Used in search results and filter panel to display
/// hashtag values in a consistent pill format.
class HashtagChip extends StatelessWidget {
  const HashtagChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  /// The hashtag text to display (without the leading '#').
  final String label;

  /// Called when the chip is tapped. If null the chip is not interactive.
  final VoidCallback? onTap;

  /// Whether this chip is currently selected/active as a filter.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          '#$label',
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: selected ? AppColors.accent : AppColors.secondary,
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
