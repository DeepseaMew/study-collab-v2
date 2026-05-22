import 'package:mobile/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Returns a stream of [SessionEntity] objects whose [scheduledAt] falls
/// within [[start], [end]] and where [uid] is the host or a member.
///
/// Zero Flutter or Firebase imports — pure Dart.
class WatchSessionsInRangeUseCase {
  const WatchSessionsInRangeUseCase(this._repository);

  final CalendarRepository _repository;

  Stream<List<SessionEntity>> call(
    String uid,
    DateTime start,
    DateTime end,
  ) =>
      _repository.watchSessionsInRange(uid, start, end);
}
