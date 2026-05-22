import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Syncs [sessions] to the signed-in Google Calendar account.
///
/// Zero Flutter or Firebase imports — pure Dart.
class SyncGCalUseCase {
  const SyncGCalUseCase(this._repository);

  final CalendarSyncRepository _repository;

  Future<SyncResult> call(List<SessionEntity> sessions) =>
      _repository.syncSessions(sessions);
}
