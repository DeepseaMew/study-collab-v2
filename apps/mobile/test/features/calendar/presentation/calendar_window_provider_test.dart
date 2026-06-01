// Unit tests for CalendarWindowNotifier.
//
// Verifies advanceToMonth() recomputes the 3-month sliding window correctly:
//   - Window is start of (month-1) → end of (month+1).
//   - Window updates when the month falls outside current bounds.
//   - Window does NOT shrink when month is inside current bounds.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_window_provider.dart';

void main() {
  tearDown(() {
    // ensure any containers created during tests are disposed.
  });

  group('CalendarWindowNotifier.advanceToMonth', () {
    test('initial window is centred on current month (start = prev month)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      final window = container.read(calendarWindowProvider);

      // Window start should be first day of previous month (month - 1).
      expect(window.start.month, (now.month - 1) == 0 ? 12 : now.month - 1);
      expect(window.start.day, 1);
    });

    test('advanceToMonth sets window for a far-future month outside bounds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Move 6 months into the future — guaranteed outside initial 3-month window.
      final now = DateTime.now();
      final futureMonth = DateTime(now.year, now.month + 6);

      container
          .read(calendarWindowProvider.notifier)
          .advanceToMonth(futureMonth);

      final window = container.read(calendarWindowProvider);

      // After advancing, start should be start of (futureMonth - 1).
      final expectedStartMonth = futureMonth.month - 1 == 0
          ? 12
          : futureMonth.month - 1;
      expect(window.start.month, expectedStartMonth);
      expect(window.start.day, 1);
    });

    test(
      'advanceToMonth to past month outside current window updates window',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final now = DateTime.now();
        final pastMonth = DateTime(now.year - 1, now.month);

        container
            .read(calendarWindowProvider.notifier)
            .advanceToMonth(pastMonth);

        final window = container.read(calendarWindowProvider);

        // Window start = start of (pastMonth - 1).
        final expectedStartYear = pastMonth.month - 1 == 0
            ? pastMonth.year - 1
            : pastMonth.year;
        final expectedStartMonth = pastMonth.month - 1 == 0
            ? 12
            : pastMonth.month - 1;
        expect(window.start.year, expectedStartYear);
        expect(window.start.month, expectedStartMonth);
      },
    );

    test('window end is last second of (month + 1)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final targetMonth = DateTime(2024, 5);
      container
          .read(calendarWindowProvider.notifier)
          .advanceToMonth(targetMonth);

      final window = container.read(calendarWindowProvider);

      // end should be last instant of June 2024 (month+1 for May is June).
      // _windowFor: endDay = DateTime(year, month+2) then subtract 1s
      // For month=5: endDay = DateTime(2024,7) → subtract 1s = 2024-06-30 23:59:59
      expect(window.end.month, 6);
      expect(window.end.year, 2024);
      expect(window.end.day, 30);
    });

    test('advanceToMonth within current window does not change state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Capture the initial window.
      final initialWindow = container.read(calendarWindowProvider);

      // Now() is always inside the initial window (centred on it).
      container
          .read(calendarWindowProvider.notifier)
          .advanceToMonth(DateTime.now());

      final windowAfter = container.read(calendarWindowProvider);

      // Should be unchanged.
      expect(windowAfter.start, initialWindow.start);
      expect(windowAfter.end, initialWindow.end);
    });

    test('window start has time 00:00:00 (midnight)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final window = container.read(calendarWindowProvider);
      expect(window.start.hour, 0);
      expect(window.start.minute, 0);
      expect(window.start.second, 0);
    });

    test(
      'advanceToMonth twice — second call with same month keeps first result',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final target = DateTime(2026, 10);
        container.read(calendarWindowProvider.notifier).advanceToMonth(target);
        final windowAfterFirst = container.read(calendarWindowProvider);

        // Advance again to same month — window is already outside initial so
        // the second call lands within the updated window bounds.
        container.read(calendarWindowProvider.notifier).advanceToMonth(target);
        final windowAfterSecond = container.read(calendarWindowProvider);

        // Target (October 2026) is within the window set by first advance, so
        // second advance should be a no-op (month is inside bounds).
        expect(windowAfterSecond.start, windowAfterFirst.start);
        expect(windowAfterSecond.end, windowAfterFirst.end);
      },
    );
  });
}
