/// Static helpers for formatting dates and times in the UI.
///
/// Accepts [DateTime] only — no Firestore types cross this boundary.
/// These methods produce display strings only — never used for business logic.
abstract final class DateFormatter {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Returns a human-readable date label: "Today", "Tomorrow", "Yesterday",
  /// or "D Mon YYYY".
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  /// Returns a time range string: "HH:mm – HH:mm".
  static String timeRange(DateTime start, DateTime end) {
    return '${_pad(start.hour)}:${_pad(start.minute)} – '
        '${_pad(end.hour)}:${_pad(end.minute)}';
  }

  /// Returns a relative time string: "just now", "X minutes ago", etc.
  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    if (d < 7) return '$d day${d == 1 ? '' : 's'} ago';
    return relativeDate(dt);
  }

  /// Formats a [DateTime] as "D Mon YYYY  HH:mm".
  static String formatDateTime(DateTime dt) {
    final hour = _pad(dt.hour);
    final min = _pad(dt.minute);
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}  $hour:$min';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
