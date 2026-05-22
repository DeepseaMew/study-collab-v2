import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/calendar/data/datasources/calendar_datasource.dart';
import 'package:mobile/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:mobile/features/calendar/domain/usecases/watch_sessions_in_range_usecase.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_sessions_provider.g.dart';

/// Provides the [CalendarRepository] wired to Firestore.
@riverpod
CalendarRepository calendarRepository(CalendarRepositoryRef ref) =>
    CalendarRepositoryImpl(
      CalendarDatasource(FirebaseFirestore.instance),
    );

/// Streams sessions for [uid] whose [scheduledAt] falls in [[windowStart], [windowEnd]].
@riverpod
Stream<List<SessionEntity>> calendarSessions(
  CalendarSessionsRef ref,
  String uid,
  DateTime windowStart,
  DateTime windowEnd,
) {
  final usecase = WatchSessionsInRangeUseCase(
    ref.watch(calendarRepositoryProvider),
  );
  return usecase(uid, windowStart, windowEnd);
}
