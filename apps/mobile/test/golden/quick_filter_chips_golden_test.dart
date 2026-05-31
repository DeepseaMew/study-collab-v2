// Golden tests for QuickFilterChipsWidget (ADR 0010).
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
import 'package:mobile/features/search/presentation/widgets/quick_filter_chips.dart';
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
  bool todayActive = false,
}) {
  return ProviderScope(
    overrides: [
      if (todayActive)
        quickFilterNotifierProvider.overrideWith(
          () => _FixedQuickFilter(today: true),
        ),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
      theme: _theme(),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: QuickFilterChipsWidget(onFilterChanged: () {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('QuickFilterChipsWidget golden', () {
    testWidgets('all unselected scale_1.0_th', (tester) async {
      await tester.pumpWidget(_buildGolden());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(QuickFilterChipsWidget),
        matchesGoldenFile(
          'goldens/quick_filter_chips_all_inactive_scale_1.0_th.png',
        ),
      );
    });

    testWidgets('all unselected scale_1.5_th', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(QuickFilterChipsWidget),
        matchesGoldenFile(
          'goldens/quick_filter_chips_all_inactive_scale_1.5_th.png',
        ),
      );
    });

    testWidgets('today active scale_1.0_th', (tester) async {
      await tester.pumpWidget(_buildGolden(todayActive: true));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(QuickFilterChipsWidget),
        matchesGoldenFile(
          'goldens/quick_filter_chips_today_active_scale_1.0_th.png',
        ),
      );
    });

    testWidgets('today active scale_1.5_th', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5, todayActive: true));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(QuickFilterChipsWidget),
        matchesGoldenFile(
          'goldens/quick_filter_chips_today_active_scale_1.5_th.png',
        ),
      );
    });
  });
}

class _FixedQuickFilter extends QuickFilterNotifier {
  _FixedQuickFilter({bool today = false}) : _today = today;

  final bool _today;

  @override
  QuickFilters build() => QuickFilters(today: _today);
}
