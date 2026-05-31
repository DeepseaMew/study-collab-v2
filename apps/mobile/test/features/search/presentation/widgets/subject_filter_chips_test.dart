// Widget tests for SubjectFilterChipsWidget (ADR 0010).
//
// Traces:
// - ADR 0010 Decision: subject chips, "All" chip, "Clear all" only when
//   a subject is selected, AND logic, onFilterChanged callback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/features/search/presentation/widgets/subject_filter_chips.dart';

/// Wraps the widget under test in a minimal ProviderScope + MaterialApp.
Widget _buildSubjectChips({VoidCallback? onFilterChanged}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SubjectFilterChipsWidget(
            onFilterChanged: onFilterChanged ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  const subjects = [
    'chemistry',
    'mathematics',
    'physics',
    'computer science',
    'economics',
    'biology',
    'english',
    'other',
  ];

  group('SubjectFilterChipsWidget — rendering', () {
    testWidgets('renders all 8 subject chips', (tester) async {
      await tester.pumpWidget(_buildSubjectChips());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      for (final subject in subjects) {
        expect(
          find.text(subject),
          findsOneWidget,
          reason: 'Expected chip for subject "$subject"',
        );
      }
    });

    testWidgets('"All" chip is present', (tester) async {
      await tester.pumpWidget(_buildSubjectChips());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('"Clear all" is NOT shown when nothing is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubjectChips());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Clear all'), findsNothing);
    });
  });

  group('SubjectFilterChipsWidget — default All state', () {
    testWidgets('"All" chip is visually selected when nothing is selected', (
      tester,
    ) async {
      // The "All" chip has backgroundColor Color(0xFF7C3AED) when selected.
      // Verify via Container decoration rather than semantics label because
      // GestureDetector-based custom chips merge semantics in a way that makes
      // find.bySemanticsLabel unreliable in the test renderer.
      await tester.pumpWidget(_buildSubjectChips());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // When no subjects are selected, the "All" text is visible and the chip
      // uses the purple active colour.
      expect(find.text('All'), findsOneWidget);

      final containers = tester.widgetList<Container>(find.byType(Container));
      // Purple active color for All chip: 0xFF7C3AED
      final hasActivePurple = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF7C3AED),
      );
      expect(
        hasActivePurple,
        isTrue,
        reason: 'Expected All chip Container with purple active color',
      );
    });
  });

  group('SubjectFilterChipsWidget — tap interactions', () {
    testWidgets('tapping a subject chip calls onFilterChanged', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _buildSubjectChips(
          onFilterChanged: () {
            callCount++;
          },
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('mathematics'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(callCount, greaterThanOrEqualTo(1));
    });

    testWidgets('"Clear all" appears after a subject chip is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubjectChips());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('physics'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Clear all'), findsOneWidget);
    });

    testWidgets(
      'tapping "All" chip clears selection and calls onFilterChanged',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          _buildSubjectChips(
            onFilterChanged: () {
              callCount++;
            },
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // First select a subject
        await tester.tap(find.text('chemistry'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.text('Clear all'), findsOneWidget);

        final callsBefore = callCount;

        // Tap All to clear
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(callCount, greaterThan(callsBefore));
        expect(find.text('Clear all'), findsNothing);
      },
    );

    testWidgets('"Clear all" tap clears selection and calls onFilterChanged', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        _buildSubjectChips(
          onFilterChanged: () {
            callCount++;
          },
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('biology'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Clear all'), findsOneWidget);

      final callsBefore = callCount;

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(callCount, greaterThan(callsBefore));
      expect(find.text('Clear all'), findsNothing);
    });

    testWidgets('tapping subject chip toggles selection visual state', (
      tester,
    ) async {
      // Verify the chip toggles via provider state change.
      Set<String>? capturedState;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedState = ref.watch(subjectFilterNotifierProvider);
              return MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: SubjectFilterChipsWidget(onFilterChanged: () {}),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Before tap: mathematics not in selected set
      expect(capturedState!.contains('mathematics'), isFalse);

      await tester.tap(find.text('mathematics'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // After tap: mathematics is in selected set
      expect(capturedState!.contains('mathematics'), isTrue);
    });
  });

  group('SubjectFilterChipsWidget — provider state via override', () {
    testWidgets('pre-selected subject is shown as selected via provider', (
      tester,
    ) async {
      // With 'economics' pre-selected: "Clear all" is visible, "All" chip
      // should use the non-active (AppColors.secondary) background.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectFilterNotifierProvider.overrideWith(
              () => _PreselectedSubjectNotifier({'economics'}),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SubjectFilterChipsWidget(onFilterChanged: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // "Clear all" must be visible when a subject is selected
      expect(find.text('Clear all'), findsOneWidget);

      // All text chip is visible
      expect(find.text('All'), findsOneWidget);

      // economics text chip is visible
      expect(find.text('economics'), findsOneWidget);
    });
  });
}

/// Stub notifier that starts with a pre-selected set.
class _PreselectedSubjectNotifier extends SubjectFilterNotifier {
  _PreselectedSubjectNotifier(this._initial);
  final Set<String> _initial;

  @override
  Set<String> build() => _initial;
}
