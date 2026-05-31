// Widget tests for SearchBarWidget (ADR 0010).
//
// Traces:
// - ADR 0010 Decision: search bar with hint text, clear button visible only
//   when text non-empty, clear clears controller and calls onChanged('')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/presentation/widgets/search_bar_widget.dart';

Widget _buildSearchBar({
  TextEditingController? controller,
  FocusNode? focusNode,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) {
  final ctrl = controller ?? TextEditingController();
  final node = focusNode ?? FocusNode();
  return MaterialApp(
    home: Scaffold(
      body: SearchBarWidget(
        controller: ctrl,
        focusNode: node,
        onChanged: onChanged ?? (_) {},
        onSubmitted: onSubmitted ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('SearchBarWidget — rendering', () {
    testWidgets('renders hint text "Search sessions, #hashtags..."', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSearchBar());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Search sessions, #hashtags...'), findsOneWidget);
    });

    testWidgets('does NOT show clear button when controller is empty', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildSearchBar());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The clear button icon is Icons.cancel — should not be present
      expect(
        find.bySemanticsLabel('Clear search text'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('clear button appears when controller has text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(_buildSearchBar(controller: controller));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Type some text
      await tester.enterText(find.byType(TextField), 'calculus');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.bySemanticsLabel('Clear search text'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('search icon is present', (tester) async {
      await tester.pumpWidget(_buildSearchBar());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('SearchBarWidget — clear button behaviour', () {
    testWidgets('clear button tap clears controller text', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(_buildSearchBar(controller: controller));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'mathematics');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(controller.text, equals('mathematics'));

      await tester.tap(find.bySemanticsLabel('Clear search text'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(controller.text, isEmpty);
      handle.dispose();
    });

    testWidgets('clear button tap calls onChanged with empty string', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      String? lastChange;

      await tester.pumpWidget(
        _buildSearchBar(
          controller: controller,
          onChanged: (val) => lastChange = val,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'physics');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.bySemanticsLabel('Clear search text'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(lastChange, equals(''));
      handle.dispose();
    });

    testWidgets('clear button disappears after controller is cleared', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(_buildSearchBar(controller: controller));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'biology');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Clear search text'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Clear search text'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Clear search text'), findsNothing);
      handle.dispose();
    });
  });

  group('SearchBarWidget — accessibility', () {
    testWidgets('TextField has Semantics label "Search sessions"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildSearchBar());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Search sessions'), findsOneWidget);
      handle.dispose();
    });
  });
}
