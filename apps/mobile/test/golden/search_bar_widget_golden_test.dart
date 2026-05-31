// Golden tests for SearchBarWidget (ADR 0010).
//
// Two states × two text scales = 4 golden images.
// Fixed locale: th. Fixed theme: AppColors + AppTypography.
//
// DO NOT run flutter test --update-goldens without human approval of
// intentional UI changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/presentation/widgets/search_bar_widget.dart';
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

Widget _buildGolden({double textScale = 1.0, String initialText = ''}) {
  final controller = TextEditingController(text: initialText);
  final focusNode = FocusNode();

  return MaterialApp(
    locale: const Locale('th'),
    theme: _theme(),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBarWidget(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) {},
            onSubmitted: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SearchBarWidget golden', () {
    testWidgets('empty state scale_1.0_th', (tester) async {
      await tester.pumpWidget(_buildGolden());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SearchBarWidget),
        matchesGoldenFile('goldens/search_bar_empty_scale_1.0_th.png'),
      );
    });

    testWidgets('empty state scale_1.5_th', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SearchBarWidget),
        matchesGoldenFile('goldens/search_bar_empty_scale_1.5_th.png'),
      );
    });

    testWidgets('with text and clear button scale_1.0_th', (tester) async {
      await tester.pumpWidget(_buildGolden(initialText: 'calculus'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SearchBarWidget),
        matchesGoldenFile('goldens/search_bar_with_text_scale_1.0_th.png'),
      );
    });

    testWidgets('with text and clear button scale_1.5_th', (tester) async {
      await tester.pumpWidget(
        _buildGolden(textScale: 1.5, initialText: 'calculus'),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SearchBarWidget),
        matchesGoldenFile('goldens/search_bar_with_text_scale_1.5_th.png'),
      );
    });
  });
}
