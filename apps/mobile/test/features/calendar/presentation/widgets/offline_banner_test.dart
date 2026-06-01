// Widget tests for OfflineBanner.
//
// Tests:
//   1. Smoke test — widget renders without error when placed in the widget tree.
//   2. Offline text is displayed.
//   3. Outer Semantics node carries the label
//      "Offline — showing last loaded schedule".
//   4. wifi_off_rounded icon is present in the tree but excluded from semantics
//      via ExcludeSemantics.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/widgets/offline_banner.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

/// Wraps [OfflineBanner] in a minimal [MaterialApp] with the app theme so that
/// [Theme.of(context).textTheme] resolves correctly inside the widget.
Widget _buildBanner() {
  return MaterialApp(
    locale: const Locale('th'),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.background,
      ),
      textTheme: AppTypography.textTheme,
      useMaterial3: true,
    ),
    home: const Scaffold(body: Column(children: [OfflineBanner()])),
  );
}

void main() {
  group('OfflineBanner', () {
    testWidgets('smoke test — renders without error', (tester) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('displays the correct offline text', (tester) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(
        find.text("You're offline — showing your last loaded schedule"),
        findsOneWidget,
      );
    });

    testWidgets(
      'Semantics node carries label "Offline — showing last loaded schedule"',
      (tester) async {
        await tester.pumpWidget(_buildBanner());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final semanticsHandle = tester.ensureSemantics();

        // The outer Semantics wrapper sets the label. Flutter merges descendant
        // text into the node label, so the full label may contain additional
        // text from child widgets. We verify the declared label is present as a
        // prefix / substring of the merged label.
        final node = tester.getSemantics(find.byType(OfflineBanner));
        expect(node.label, contains('Offline — showing last loaded schedule'));

        semanticsHandle.dispose();
      },
    );

    testWidgets('wifi_off_rounded icon is in the widget tree', (tester) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('wifi_off_rounded icon is wrapped in ExcludeSemantics', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Confirm that ExcludeSemantics is present as an ancestor of the icon.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.wifi_off_rounded),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('icon has no independent semantics label of its own', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final semanticsHandle = tester.ensureSemantics();

      // The icon is inside ExcludeSemantics. When Flutter merges semantics the
      // icon's subtree is suppressed: the semantics node reachable from the
      // icon widget is the merged outer Semantics node — it carries the banner
      // label, not an icon-specific label. We verify the icon contributes no
      // label text of its own.
      final node = tester.getSemantics(find.byIcon(Icons.wifi_off_rounded));
      // The node label must NOT contain any icon-specific label; it will be
      // either empty or the merged banner label (which contains no icon text).
      expect(node.label, isNot(contains('wifi')));
      expect(node.label, isNot(contains('offline icon')));

      semanticsHandle.dispose();
    });
  });
}
