import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';

/// Reads the current user's email from [UserRepository] then initiates
/// Google Calendar OAuth via [CalendarSyncRepository.connect].
///
/// Zero Flutter or Firebase imports — pure Dart.
class ConnectGCalUseCase {
  const ConnectGCalUseCase({
    required CalendarSyncRepository syncRepository,
    required UserRepository userRepository,
    required String uid,
  })  : _syncRepository = syncRepository,
        _userRepository = userRepository,
        _uid = uid;

  final CalendarSyncRepository _syncRepository;
  final UserRepository _userRepository;
  final String _uid;

  /// Connects GCal for the user identified by [_uid].
  ///
  /// Throws [EmailMismatchError], [CancelledError], or [ApiFailureError]
  /// propagated from the repository layer.
  Future<void> call() async {
    final user = await _userRepository.watchUser(_uid).first;
    if (user == null) {
      throw StateError('User document not found for uid');
    }
    await _syncRepository.connect(user.email);
  }
}
