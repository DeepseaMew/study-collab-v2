import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// One entry in the quick-filter chip row.
class _QuickChipDef {
  const _QuickChipDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.activeColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color activeColor;
}

const _kChips = [
  _QuickChipDef(
    key: 'today',
    label: 'Today',
    icon: Icons.today,
    activeColor: Color(0xFF16A34A), // green-600
  ),
  _QuickChipDef(
    key: 'thisWeek',
    label: 'This Week',
    icon: Icons.date_range,
    activeColor: Color(0xFF2563EB), // blue-600
  ),
  _QuickChipDef(
    key: 'myLevel',
    label: 'My Level',
    icon: Icons.school,
    activeColor: Color(0xFF7C3AED), // purple-700
  ),
  _QuickChipDef(
    key: 'friends',
    label: 'Friends',
    icon: Icons.people,
    activeColor: Color(0xFFD97706), // amber-600
  ),
];

/// Horizontally scrollable row of four quick-filter chips.
///
/// Reads [quickFilterNotifierProvider] and calls [onFilterChanged] after each
/// toggle so the parent can re-trigger the search.
///
/// The Friends chip is wrapped in a [Tooltip] indicating it is coming soon
/// until the Friends filter ADR is defined and the feature is wired.
class QuickFilterChipsWidget extends ConsumerWidget {
  const QuickFilterChipsWidget({super.key, required this.onFilterChanged});

  final VoidCallback onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickFilterNotifierProvider);
    final notifier = ref.read(quickFilterNotifierProvider.notifier);

    bool isActive(String key) => switch (key) {
          'today' => state.today,
          'thisWeek' => state.thisWeek,
          'myLevel' => state.myLevel,
          'friends' => state.friends,
          _ => false,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row header
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'QUICK FILTERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.hint,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Horizontally scrollable chips.
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _kChips.length,
            itemBuilder: (context, index) {
              final chip = _kChips[index];
              final active = isActive(chip.key);
              final isFriends = chip.key == 'friends';

              final chipWidget = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  label:
                      '${chip.label} quick filter, ${active ? "active" : "inactive"}',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      notifier.toggle(chip.key);
                      onFilterChanged();
                    },
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? chip.activeColor
                              : chip.activeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? chip.activeColor
                                : chip.activeColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              chip.icon,
                              size: 16,
                              color: active ? Colors.white : chip.activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chip.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : chip.activeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              if (isFriends) {
                return Tooltip(
                  message: 'Coming soon — friends filter',
                  child: chipWidget,
                );
              }
              return chipWidget;
            },
          ),
        ),
      ],
    );
  }
}
