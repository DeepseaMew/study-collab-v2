import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Domain repository interface for reading session data for calendar display.
///
/// Zero Flutter or Firebase imports — pure Dart.
abstract interface class CalendarRepository {
  /// Streams sessions where [uid] is the host or a member, whose
  /// [SessionEntity.scheduledAt] falls within [[start], [end]] (inclusive).
  Stream<List<SessionEntity>> watchSessionsInRange(
    String uid,
    DateTime start,
    DateTime end,
  );
}
