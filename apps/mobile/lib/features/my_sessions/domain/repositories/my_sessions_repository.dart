import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Abstract repository interface for the My Sessions feature.
///
/// Provides three independent streams, one per My Sessions tab.
/// Implementations live in `data/repositories/`.
abstract interface class MySessionsRepository {
  /// Watches sessions the user is a member of that have NOT ended yet.
  ///
  /// Implementation note (ADR 0003 sub-decision 1): reuses Firestore Index 1
  /// (`memberUids array-contains, scheduledAt asc`) and applies a client-side
  /// `status != 'ended'` filter in the repository layer.
  Stream<List<SessionEntity>> watchUpcomingSessions(String uid);

  /// Watches sessions the user is a member of that have ended.
  ///
  /// Uses Firestore Index 2 (`memberUids array-contains, status asc, endedAt desc`).
  Stream<List<SessionEntity>> watchCompletedSessions(String uid);

  /// Watches sessions the user is hosting, ordered by [SessionEntity.scheduledAt] descending.
  ///
  /// Uses Firestore Index 9 (`hostUid asc, scheduledAt desc`).
  Stream<List<SessionEntity>> watchHostedSessions(String uid);
}
