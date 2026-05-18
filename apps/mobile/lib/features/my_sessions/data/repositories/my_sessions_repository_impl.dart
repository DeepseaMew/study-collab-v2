import 'package:mobile/features/my_sessions/data/datasources/my_sessions_datasource.dart';
import 'package:mobile/features/my_sessions/domain/repositories/my_sessions_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Firestore implementation of [MySessionsRepository].
///
/// Both Upcoming and Completed use Index 1 (memberUids, scheduledAt asc) and
/// split purely on client-side time per ADR 0003 sub-decision 1 Option A:
/// - Upcoming:  scheduledEndAt in the future AND status != 'ended'
/// - Completed: scheduledEndAt <= now OR status == 'ended'
/// Private sessions hosted by the caller are excluded from both streams —
/// they surface only in watchHostedSessions.
class MySessionsRepositoryImpl implements MySessionsRepository {
  MySessionsRepositoryImpl(this._datasource);

  final MySessionsDatasource _datasource;

  static bool _excludePrivateOwnedByHost(dynamic m, String uid) =>
      !(m.visibility == 'private' && m.hostUid == uid);

  // A session is upcoming if it has not been explicitly ended and its
  // scheduled end time is still in the future. Legacy docs with no
  // scheduledEndAt fall back to status-only check.
  static bool _isUpcoming(dynamic m, DateTime now) {
    if (m.status == 'ended') return false;
    final endAt = m.scheduledEndAt as DateTime?;
    if (endAt == null) return true;
    return endAt.isAfter(now);
  }

  // A session is completed if it was explicitly ended OR its scheduled end
  // time has passed. Legacy docs with no scheduledEndAt are completed only
  // when status == 'ended'.
  static bool _isCompleted(dynamic m, DateTime now) {
    if (m.status == 'ended') return true;
    final endAt = m.scheduledEndAt as DateTime?;
    if (endAt == null) return false;
    return !endAt.isAfter(now);
  }

  @override
  Stream<List<SessionEntity>> watchUpcomingSessions(String uid) {
    return _datasource.watchMemberSessionsForUpcoming(uid).map((models) {
      final now = DateTime.now();
      return models
          .where(
            (m) => _isUpcoming(m, now) && _excludePrivateOwnedByHost(m, uid),
          )
          .map((m) => m.toEntity())
          .toList();
    });
  }

  @override
  Stream<List<SessionEntity>> watchCompletedSessions(String uid) {
    return _datasource.watchMemberSessionsForUpcoming(uid).map((models) {
      final now = DateTime.now();
      return models
          .where(
            (m) => _isCompleted(m, now) && _excludePrivateOwnedByHost(m, uid),
          )
          .map((m) => m.toEntity())
          .toList();
    });
  }

  @override
  Stream<List<SessionEntity>> watchHostedSessions(String uid) {
    return _datasource
        .watchHostedSessions(uid)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
