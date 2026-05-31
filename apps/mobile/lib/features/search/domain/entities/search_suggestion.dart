import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_suggestion.freezed.dart';

/// Categorises a search suggestion by where it originated.
enum SuggestionType {
  /// Previously searched term restored from local secure storage.
  recent,

  /// Matched against a session title from loaded results.
  sessionName,

  /// Matched against a session hashtag from loaded results.
  hashtag,

  /// Matched against the host display name from loaded results.
  host,
}

/// Immutable value object representing a single search suggestion.
///
/// Domain-pure: zero Flutter or Firebase imports.
@freezed
abstract class SearchSuggestion with _$SearchSuggestion {
  const factory SearchSuggestion({
    /// The text shown in the suggestion row and filled into the search bar
    /// when tapped.
    required String displayText,

    /// Indicates where this suggestion originated so the overlay can choose
    /// the correct leading icon and styling.
    required SuggestionType type,

    /// Optional subject label rendered as a trailing chip (session name
    /// suggestions may carry the session subject/hashtag context).
    String? subject,
  }) = _SearchSuggestion;
}
