// Golden tests for SubjectFilterChipsWidget (ADR 0010).
//
// Two states × two text scales = 4 golden images.
// Fixed locale: th. Fixed theme: AppColors + AppTypography.
//
// DO NOT run flutter test --update-goldens without human approval of
// intentional UI changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/features/search/presentation/widgets/subject_filter_chips.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

ThemeData _theme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.background,
      ),
      textTheme: AppTypography.textTheme,
      useMaterial3: true,
    );

Widget _buildGolden({
  double textScale = 1.0,
  Set<String> selected = const {},
}) {
  return ProviderScope(
    overrides: [
      if (selected.isNotEmpty)
        subjectFilterNotifierProvider.overrideWith(
          () => _FixedSubjectNotifier(selected),
        ),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
      theme: _theme(),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SubjectFilterChipsWidget(onFilterChanged: () {}),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SubjectFilterChipsWidget golden', () {
    testWidgets('unselected state scale_1.0_th', (tester) async {
      await tester.pumpWidget(_buildGolden());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SubjectFilterChipsWidget),
        matchesGoldenFile(
          'goldens/subject_filter_chips_unselected_scale_1.0_th.png',
        ),
      );
    });

    testWidgets('unselected state scale_1.5_th', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SubjectFilterChipsWidget),
        matchesGoldenFile(
          'goldens/subject_filter_chips_unselected_scale_1.5_th.png',
        ),
      );
    });

    testWidgets('one subject selected state scale_1.0_th', (tester) async {
      await tester.pumpWidget(
        _buildGolden(selected: {'mathematics'}),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SubjectFilterChipsWidget),
        matchesGoldenFile(
          'goldens/subject_filter_chips_selected_scale_1.0_th.png',
        ),
      );
    });

    testWidgets('one subject selected state scale_1.5_th', (tester) async {
      await tester.pumpWidget(
        _buildGolden(textScale: 1.5, selected: {'mathematics'}),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SubjectFilterChipsWidget),
        matchesGoldenFile(
          'goldens/subject_filter_chips_selected_scale_1.5_th.png',
        ),
      );
    });
  });
}

class _FixedSubjectNotifier extends SubjectFilterNotifier {
  _FixedSubjectNotifier(this._fixed);
  final Set<String> _fixed;

  @override
  Set<String> build() => _fixed;
}
