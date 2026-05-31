/// Domain errors for the Search feature (ADR 0010).
///
/// All variants are sealed subclasses of [SearchError]. No PII may appear
/// in any error message field — only error codes and generic descriptions
/// are permitted.
sealed class SearchError implements Exception {
  const SearchError();

  /// The search query is non-empty but shorter than 2 characters after trimming.
  const factory SearchError.queryTooShort() = SearchQueryTooShort;

  /// Search requires an active network connection.
  /// Thrown when Firestore returns an unavailable error.
  const factory SearchError.offlineNotSupported() = SearchOfflineNotSupported;

  /// An unexpected error occurred. [message] must contain no PII.
  const factory SearchError.unknown(String message) = SearchUnknown;
}

final class SearchQueryTooShort extends SearchError {
  const SearchQueryTooShort();

  @override
  String toString() => 'SearchError.queryTooShort';
}

final class SearchOfflineNotSupported extends SearchError {
  const SearchOfflineNotSupported();

  @override
  String toString() => 'SearchError.offlineNotSupported';
}

final class SearchUnknown extends SearchError {
  const SearchUnknown(this.message);
  final String message;

  @override
  String toString() => 'SearchError.unknown(message=$message)';
}
