import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';

/// Disconnects the Google Calendar sync for the current user.
///
/// Zero Flutter or Firebase imports — pure Dart.
class DisconnectGCalUseCase {
  const DisconnectGCalUseCase(this._repository);

  final CalendarSyncRepository _repository;

  Future<void> call() => _repository.disconnect();
}
