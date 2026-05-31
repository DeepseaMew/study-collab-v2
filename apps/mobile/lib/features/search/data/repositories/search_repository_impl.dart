import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mobile/core/errors/search_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/search/data/datasources/search_datasource.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/domain/repositories/search_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Implements [SearchRepository] using [SearchDatasource] for Firestore reads
/// and applies client-side AND post-filtering (ADR 0010 Sub-decision 2).
///
/// Firestore → [SessionModel] → client-side AND filter → [SessionEntity].
///
/// Maps [FirebaseException] with code `'unavailable'` to
/// [SearchError.offlineNotSupported]. All other exceptions are mapped to
/// [SearchError.unknown] and recorded as non-fatals in Crashlytics.
class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl(this._datasource);

  final SearchDatasource _datasource;

  @override
  Future<List<SessionEntity>> searchSessions(SearchFilter filter) async {
    try {
      final models = await _datasource.searchSessions(filter);

      final now = DateTime.now();
      final entities = models
          .map((m) => m.toEntity())
          .where((s) => _matchesFilter(s, filter, now))
          .toList();

      appLogger.info(
        'SearchRepositoryImpl.searchSessions complete',
        extra: {'resultCount': entities.length},
      );

      return entities;
    } on FirebaseException catch (e, st) {
      // 'unavailable' is handled by the datasource cache fallback — if it
      // reaches here it means both server and cache failed; treat as unknown.
      appLogger.error(
        'SearchRepositoryImpl: FirebaseException',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'SearchRepositoryImpl.searchSessions FirebaseException',
      );
      throw SearchError.unknown(e.code);
    } catch (e, st) {
      appLogger.error(
        'SearchRepositoryImpl: unexpected error',
        exception: e,
        stackTrace: st,
      );
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'SearchRepositoryImpl.searchSessions unexpected',
      );
      throw SearchError.unknown(e.runtimeType.toString());
    }
  }

  /// Applies client-side AND logic across all active filter dimensions.
  bool _matchesFilter(
    SessionEntity session,
    SearchFilter filter,
    DateTime now,
  ) {
    // Only show scheduled, future sessions — replaces the server-side filter
    // that was removed to avoid requiring a composite index (ADR 0001).
    if (session.status != 'scheduled') return false;
    if (session.scheduledAt.isBefore(now)) return false;

    // Keyword / host search: branch on whether query starts with '@'.
    if (filter.query != null && filter.query!.isNotEmpty) {
      if (filter.query!.startsWith('@')) {
        // Host search: match displayName (case-insensitive substring).
        final handle = filter.query!.substring(1).trim().toLowerCase();
        if (handle.isNotEmpty &&
            !session.hostDisplayName.toLowerCase().contains(handle)) {
          return false;
        }
      } else {
        // Keyword: match title (case-insensitive substring).
        if (!session.title.toLowerCase().contains(filter.query!.toLowerCase())) {
          return false;
        }
      }
    }

    // Hashtag: exact equality match (already lowercased by use case).
    if (filter.hashtag != null) {
      if (!session.hashtags.any((h) => h == filter.hashtag)) {
        return false;
      }
    }

    // Academic level: exact equality.
    if (filter.academicLevel != null) {
      if (session.academicLevel != filter.academicLevel) {
        return false;
      }
    }

    // Student year: exact equality.
    if (filter.studentYear != null) {
      if (session.studentYear != filter.studentYear) {
        return false;
      }
    }

    // Date range: applied client-side on scheduledAt.
    if (filter.dateRange != null) {
      switch (filter.dateRange!) {
        case SearchDateRange.today:
          final todayStart = DateTime(now.year, now.month, now.day);
          final todayEnd = todayStart.add(const Duration(days: 1));
          if (session.scheduledAt.isBefore(todayStart) ||
              !session.scheduledAt.isBefore(todayEnd)) {
            return false;
          }
        case SearchDateRange.thisWeek:
          final weekdayOffset = now.weekday - 1; // Monday = 1
          final weekStart = DateTime(
            now.year,
            now.month,
            now.day - weekdayOffset,
          );
          final weekEnd = weekStart.add(const Duration(days: 7));
          if (session.scheduledAt.isBefore(weekStart) ||
              !session.scheduledAt.isBefore(weekEnd)) {
            return false;
          }
        case SearchDateRange.myLevel:
          // myLevel is resolved to academicLevel by SearchFilterNotifier;
          // by the time the filter reaches here, academicLevel is already set.
          // Nothing additional to filter here.
          break;
      }
    }

    // Subjects: AND logic — the session must have ALL selected subjects in its
    // hashtags list (each subject chip value is stored as a hashtag).
    if (filter.subjects != null && filter.subjects!.isNotEmpty) {
      for (final subject in filter.subjects!) {
        if (!session.hashtags.any((h) => h == subject)) {
          return false;
        }
      }
    }

    return true;
  }
}
