import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Abstract repository interface for the search feature (ADR 0010).
///
/// Implementations live in the data layer. This interface imports only
/// domain types — zero Flutter or Firebase imports.
abstract interface class SearchRepository {
  /// Searches public scheduled sessions matching [filter].
  ///
  /// Returns a list of [SessionEntity] sorted by [scheduledAt] ascending.
  /// Throws [SearchError.offlineNotSupported] when the device is offline.
  /// Throws [SearchError.queryTooShort] when a keyword is present but < 2 chars
  /// (enforced by [SearchSessionsUseCase] before reaching this method).
  Future<List<SessionEntity>> searchSessions(SearchFilter filter);
}
