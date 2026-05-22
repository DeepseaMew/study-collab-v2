// Integration test scaffold for the Calendar feature.
//
// Scenarios from ADR 0007:
//   1. Calendar screen loads and shows TableCalendar.
//   2. Tapping a day updates the session-list panel.
//   3. Month/week toggle switches the calendar format.
//   4. Overflow pill navigates to CalendarDayScreen.
//
// Test bodies are intentionally left as TODOs — they must run against a live
// Firebase emulator wired in CI. Do NOT run this file locally without the
// emulator stack running.
//
// CI command:
//   flutter test integration_test/calendar_integration_test.dart \
//     --dart-define=USE_EMULATOR=true

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar feature — integration (emulator required)', () {
    // ── Scenario 1 ─────────────────────────────────────────────────────────
    testWidgets(
      'Calendar screen loads and shows TableCalendar widget',
      (tester) async {
        // TODO: run against emulator
        // Steps:
        //   1. Sign in with a seeded KMUTT test account via Firebase Auth emulator.
        //   2. Navigate to /calendar via GoRouter.
        //   3. pumpAndSettle(const Duration(seconds: 5)).
        //   4. expect(find.byType(TableCalendar), findsOneWidget).
      },
    );

    // ── Scenario 2 ─────────────────────────────────────────────────────────
    testWidgets(
      'Tapping a calendar day updates the session-list panel',
      (tester) async {
        // TODO: run against emulator
        // Steps:
        //   1. Sign in and navigate to /calendar.
        //   2. Seed at least one session in the emulator Firestore for today's date.
        //   3. pumpAndSettle to allow stream to emit.
        //   4. Tap on today's day cell (find by day number text).
        //   5. pumpAndSettle(const Duration(seconds: 3)).
        //   6. Verify _DaySessionsPanel is shown (find.textContaining('sessions')).
        //   7. Verify "Tap a day to see sessions" is no longer visible.
      },
    );

    // ── Scenario 3 ─────────────────────────────────────────────────────────
    testWidgets(
      'Month/week toggle switches the calendar format',
      (tester) async {
        // TODO: run against emulator
        // Steps:
        //   1. Sign in and navigate to /calendar.
        //   2. pumpAndSettle to render initial monthly view.
        //   3. Confirm SegmentedButton<CalendarFormat> is present.
        //   4. Tap the 'Week' segment button.
        //   5. pumpAndSettle(const Duration(seconds: 2)).
        //   6. Verify CalendarFormat.week is now selected
        //      (the SegmentedButton selected set contains CalendarFormat.week).
        //   7. Tap 'Month' segment button and verify format reverts.
      },
    );

    // ── Scenario 4 ─────────────────────────────────────────────────────────
    testWidgets(
      'Overflow pill navigates to CalendarDayScreen',
      (tester) async {
        // TODO: run against emulator
        // Steps:
        //   1. Sign in and navigate to /calendar.
        //   2. Seed >3 sessions for a single day in Firestore emulator.
        //   3. pumpAndSettle to allow stream to populate event markers.
        //   4. Tap the day cell that has >3 sessions.
        //   5. pumpAndSettle(const Duration(seconds: 2)).
        //   6. Tap the overflow pill ('+ N more sessions — see all')
        //      or the 'See all →' TextButton.
        //   7. pumpAndSettle(const Duration(seconds: 3)).
        //   8. Verify GoRouter has pushed /calendar/day
        //      (find.byType(CalendarDayScreen) findsOneWidget).
        //   9. Verify the count label shows the correct session total.
      },
    );
  });
}
