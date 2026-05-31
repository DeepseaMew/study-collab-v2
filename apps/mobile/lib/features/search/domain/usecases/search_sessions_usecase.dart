import 'package:mobile/core/errors/search_error.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/domain/repositories/search_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Validates and normalises a [SearchFilter] then delegates to [SearchRepository].
///
/// Business rules (ADR 0010):
/// - Trims whitespace from [query] and [hashtag].
/// - Lowercases [query] and [hashtag].
/// - Throws [SearchError.queryTooShort] if the trimmed, non-empty [query] is
///   shorter than 2 characters.
/// - Does not catch errors — propagates them so the presentation layer
///   and repository can handle them appropriately.
///
/// Zero Flutter or Firebase imports — pure Dart.
class SearchSessionsUseCase {
  const SearchSessionsUseCase(this._repository);

  final SearchRepository _repository;

  /// Executes the search with normalised filter values.
  Future<List<SessionEntity>> call(SearchFilter filter) {
    final rawQuery = filter.query?.trim();
    final normalisedQuery =
        (rawQuery != null && rawQuery.isNotEmpty) ? rawQuery.toLowerCase() : null;

    if (normalisedQuery != null && normalisedQuery.length < 2) {
      throw const SearchError.queryTooShort();
    }

    final rawHashtag = filter.hashtag?.trim();
    final normalisedHashtag =
        (rawHashtag != null && rawHashtag.isNotEmpty)
            ? rawHashtag.toLowerCase()
            : null;

    final normalisedFilter = filter.copyWith(
      query: normalisedQuery,
      hashtag: normalisedHashtag,
    );

    return _repository.searchSessions(normalisedFilter);
  }
}
