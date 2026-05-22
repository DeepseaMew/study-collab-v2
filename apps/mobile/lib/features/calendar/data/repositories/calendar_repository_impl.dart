import 'package:mobile/features/calendar/data/datasources/calendar_datasource.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Firestore implementation of [CalendarRepository].
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._datasource);

  final CalendarDatasource _datasource;

  @override
  Stream<List<SessionEntity>> watchSessionsInRange(
    String uid,
    DateTime start,
    DateTime end,
  ) {
    return _datasource
        .watchSessionsInRange(uid, start, end)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
