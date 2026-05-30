import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_window_provider.g.dart';

/// Holds the Firestore query window for the calendar — a 3-month rolling range
/// centred on the currently viewed month.
///
/// Business logic: the window only expands; it never contracts. This avoids
/// re-querying Firestore when the user flips between months already inside the
/// current window.
@Riverpod(keepAlive: true)
class CalendarWindow extends _$CalendarWindow {
  @override
  ({DateTime start, DateTime end}) build() => _windowFor(DateTime.now());

  ({DateTime start, DateTime end}) _windowFor(DateTime month) {
    final start = DateTime(month.year, month.month - 1);
    // month+2, day 0 = last day of month+1; time set to end of day.
    final endDay = DateTime(month.year, month.month + 2);
    final end = endDay.subtract(const Duration(seconds: 1));
    return (start: start, end: end);
  }

  /// Expands the query window when [month] falls outside the current bounds.
  void advanceToMonth(DateTime month) {
    final current = state;
    final candidate = _windowFor(month);
    if (month.isBefore(current.start) || month.isAfter(current.end)) {
      state = candidate;
    }
  }
}
