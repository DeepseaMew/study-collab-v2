// Widget tests for ProfileScoreWidget (ADR 0009).
//
// Verifies:
//   - Renders "No ratings yet" text and semantics when profileScore == 0.0
//   - Renders formatted percentage and semantics for score > 0
//   - Percentage string matches (score * 100).toStringAsFixed(0)
//   - Semantics labels are correct for accessibility

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rating/presentation/widgets/profile_score_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('ProfileScoreWidget — zero score', () {
    testWidgets('renders "No ratings yet" text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(profileScore: 0.0, completedSessionCount: 0),
        ),
      );

      expect(find.text('No ratings yet'), findsOneWidget);
    });

    testWidgets('does NOT render a percentage string', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(profileScore: 0.0, completedSessionCount: 0),
        ),
      );

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('Semantics label is "No ratings yet"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(profileScore: 0.0, completedSessionCount: 0),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'No ratings yet',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders outlined thumbs-up icon (zero state)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(profileScore: 0.0, completedSessionCount: 0),
        ),
      );

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });
  });

  group('ProfileScoreWidget — positive score', () {
    testWidgets('renders "85%" for score 0.85', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.85,
            completedSessionCount: 4,
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('renders "100%" for score 1.0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 1.0,
            completedSessionCount: 2,
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders "50%" for score 0.5', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.5,
            completedSessionCount: 6,
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('renders "1%" for score 0.014 (rounds down)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.014,
            completedSessionCount: 10,
          ),
        ),
      );

      expect(find.text('1%'), findsOneWidget);
    });

    testWidgets('Semantics label includes percentage and "percent positive rating"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.85,
            completedSessionCount: 4,
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '85 percent positive rating',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders filled thumbs-up icon (positive state)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.75,
            completedSessionCount: 3,
          ),
        ),
      );

      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });

    testWidgets('renders completedSessionCount in "from N sessions" text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScoreWidget(
            profileScore: 0.75,
            completedSessionCount: 7,
          ),
        ),
      );

      expect(find.textContaining('from 7 sessions'), findsOneWidget);
    });
  });
}
