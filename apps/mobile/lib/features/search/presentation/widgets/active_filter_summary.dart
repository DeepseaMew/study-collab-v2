import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/search/presentation/providers/filter_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';

/// Displays a row of dismissible purple pill chips representing every currently
/// active filter (subjects, quick-filters, academicLevel, studentYear,
/// dateRange). Visible only when at least one filter is active.
///
/// Tapping the ✕ on an individual chip removes only that filter.
/// The "Reset all" link on the right clears all three notifiers and calls
/// [onResetAll].
class ActiveFilterSummaryWidget extends ConsumerWidget {
  const ActiveFilterSummaryWidget({super.key, required this.onResetAll});

  final VoidCallback onResetAll;

  static const _kBg = Color(0xFFF5F3FF);
  static const _kBorder = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectFilterNotifierProvider);
    final quickFilters = ref.watch(quickFilterNotifierProvider);
    final searchFilter = ref.watch(searchFilterNotifierProvider);

    // Build the full list of active filter pills.
    final pills = <_FilterPill>[];

    for (final subject in subjects) {
      pills.add(
        _FilterPill(
          label: subject,
          onRemove: () {
            ref.read(subjectFilterNotifierProvider.notifier).toggle(subject);
            onResetAll();
          },
        ),
      );
    }

    if (quickFilters.today) {
      pills.add(
        _FilterPill(
          label: 'Today',
          onRemove: () {
            ref.read(quickFilterNotifierProvider.notifier).toggle('today');
            onResetAll();
          },
        ),
      );
    }
    if (quickFilters.thisWeek) {
      pills.add(
        _FilterPill(
          label: 'This Week',
          onRemove: () {
            ref.read(quickFilterNotifierProvider.notifier).toggle('thisWeek');
            onResetAll();
          },
        ),
      );
    }
    if (quickFilters.myLevel) {
      pills.add(
        _FilterPill(
          label: 'My Level',
          onRemove: () {
            ref.read(quickFilterNotifierProvider.notifier).toggle('myLevel');
            onResetAll();
          },
        ),
      );
    }
    if (quickFilters.friends) {
      pills.add(
        _FilterPill(
          label: 'Friends',
          onRemove: () {
            ref.read(quickFilterNotifierProvider.notifier).toggle('friends');
            onResetAll();
          },
        ),
      );
    }

    if (searchFilter.academicLevel != null) {
      final level = searchFilter.academicLevel!;
      pills.add(
        _FilterPill(
          label: 'Level: $level',
          onRemove: () {
            ref
                .read(searchFilterNotifierProvider.notifier)
                .updateFilter(searchFilter.copyWith(academicLevel: null));
            onResetAll();
          },
        ),
      );
    }
    if (searchFilter.studentYear != null) {
      final year = searchFilter.studentYear!;
      pills.add(
        _FilterPill(
          label: 'Year $year',
          onRemove: () {
            ref
                .read(searchFilterNotifierProvider.notifier)
                .updateFilter(searchFilter.copyWith(studentYear: null));
            onResetAll();
          },
        ),
      );
    }

    // If nothing is active, render nothing.
    if (pills.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kBg,
        border: Border(
          bottom: BorderSide(color: _kBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pills,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onResetAll,
            child: const Text(
              'Reset all',
              style: TextStyle(
                fontSize: 11,
                color: _kBorder,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single dismissible filter pill chip.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  static const _kPurple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label filter active, tap to remove',
      button: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kPurple,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
