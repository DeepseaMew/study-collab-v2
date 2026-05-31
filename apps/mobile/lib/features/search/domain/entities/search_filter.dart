import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_filter.freezed.dart';

/// Quick-filter date range options for the search screen.
///
/// [myLevel] is a UI convenience alias that is resolved to the current user's
/// [academicLevel] string in [SearchFilterNotifier] before the filter reaches
/// the datasource. It never appears in Firestore queries.
enum SearchDateRange {
  /// Sessions scheduled for today only.
  today,

  /// Sessions scheduled within the current calendar week.
  thisWeek,

  /// Sessions whose [academicLevel] matches the current user's academic level.
  myLevel,
}

/// Value object that captures all active search filter dimensions.
///
/// All fields are nullable; a null value means the dimension is inactive.
/// Domain layer only — zero Flutter or Firebase imports.
@freezed
abstract class SearchFilter with _$SearchFilter {
  const factory SearchFilter({
    /// Free-text keyword matched against session title (client-side).
    /// Trimmed and lowercased before use.
    String? query,

    /// Hashtag filter. Matched via Firestore arrayContains (Index 3) when set.
    /// Trimmed and lowercased before use.
    String? hashtag,

    /// Filters sessions by [SessionEntity.academicLevel] equality.
    String? academicLevel,

    /// Filters sessions by [SessionEntity.studentYear] equality.
    int? studentYear,

    /// Quick date-range chip selection. Applied client-side on [scheduledAt].
    /// [SearchDateRange.myLevel] is resolved to [academicLevel] before querying.
    SearchDateRange? dateRange,

    /// Subject chip multi-select (AND logic). Each value is matched against
    /// [SessionEntity.hashtags]. When non-null and non-empty, the session must
    /// contain ALL selected subjects in its hashtags list.
    /// Values are lowercase (e.g. 'mathematics', 'computer science').
    Set<String>? subjects,
  }) = _SearchFilter;
}
