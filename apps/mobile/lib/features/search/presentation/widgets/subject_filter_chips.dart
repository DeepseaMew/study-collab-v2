import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/subject_colors.dart';

/// The fixed list of subject options shown as filter chips.
const _kSubjects = [
  'chemistry',
  'mathematics',
  'physics',
  'computer science',
  'economics',
  'biology',
  'english',
  'other',
];

/// Wrapping row of subject filter chips.
///
/// Reads [subjectFilterNotifierProvider] and calls [onFilterChanged] after
/// each toggle so the parent can re-trigger the search.
class SubjectFilterChipsWidget extends ConsumerWidget {
  const SubjectFilterChipsWidget({super.key, required this.onFilterChanged});

  final VoidCallback onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(subjectFilterNotifierProvider);
    final notifier = ref.read(subjectFilterNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUBJECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.hint,
                  letterSpacing: 0.5,
                ),
              ),
              if (selected.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    notifier.clear();
                    onFilterChanged();
                  },
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Wrapping chip row — chips flow to the next line when they overflow.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            children: [
              _AllChip(
                isAll: selected.isEmpty,
                onTap: () {
                  notifier.clear();
                  onFilterChanged();
                },
              ),
              ..._kSubjects.map(
                (subject) => _SubjectChip(
                  subject: subject,
                  isSelected: selected.contains(subject),
                  onTap: () {
                    notifier.toggle(subject);
                    onFilterChanged();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllChip extends StatelessWidget {
  const _AllChip({required this.isAll, required this.onTap});

  final bool isAll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All subjects filter, ${isAll ? "selected" : "unselected"}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAll ? const Color(0xFF7C3AED) : AppColors.secondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAll ? const Color(0xFF7C3AED) : AppColors.border,
            ),
          ),
          child: Text(
            'All',
            style: TextStyle(
              color: isAll ? Colors.white : AppColors.hint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subject,
    required this.isSelected,
    required this.onTap,
  });

  final String subject;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = subjectColor(subject);
    return Semantics(
      label: '$subject filter, ${isSelected ? "selected" : "unselected"}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? colors.border : colors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            subject,
            style: TextStyle(
              color: isSelected ? Colors.white : colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
