import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/note_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';
import 'package:mobile/features/note_sharing/domain/usecases/delete_note_usecase.dart';
import 'package:mobile/features/note_sharing/domain/usecases/upload_note_usecase.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_repository_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_actions_provider.g.dart';

/// Async notifier managing upload and delete actions for a session's notes
/// (ADR 0008).
///
/// State is [AsyncValue<void>] — consumers watch it to surface a
/// [LinearProgressIndicator] while loading and error banners on failure.
@riverpod
class NoteActionsNotifier extends _$NoteActionsNotifier {
  @override
  FutureOr<void> build(String sessionId) {
    // Initial state is void (no action in progress).
  }

  /// Uploads a note file after checking the feature flag.
  ///
  /// Sets state to [AsyncLoading] during the operation.
  /// On success, fires the [AnalyticsEvents.noteUploaded] event.
  /// On [NoteError], sets state to [AsyncError] so the UI can surface the
  /// correct error message per variant.
  Future<void> upload(NoteUploadParams params) async {
    final flagEnabled = ref.read(noteSharingEnabledProvider);
    if (!flagEnabled) {
      state = AsyncError<void>(
        const NoteError.uploadFailed('note_sharing_disabled'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading<void>();
    final repository = ref.read(noteRepositoryProvider);
    final useCase = UploadNoteUseCase(repository);

    state = await AsyncValue.guard(() async {
      await useCase.call(sessionId, params);
      appLogger.info(
        'note_upload: upload succeeded',
        extra: {'mimeType': params.mimeType, 'sizeBytes': params.sizeBytes},
      );
      appLogger.debug(AnalyticsEvents.noteUploaded);
    });

    if (state is AsyncError) {
      final error = (state as AsyncError<void>).error;
      final errorType = _errorTypeLabel(error);
      appLogger.error(
        'note_upload: action failed errorType=$errorType',
        exception: error,
      );
      appLogger.debug(
        '${AnalyticsEvents.noteUploadFailed} error_type=$errorType',
      );
    }
  }

  /// Deletes a note.
  ///
  /// Sets state to [AsyncLoading] during the operation.
  /// On success, fires the [AnalyticsEvents.noteDeleted] event.
  Future<void> delete(String noteId) async {
    state = const AsyncLoading<void>();
    final repository = ref.read(noteRepositoryProvider);
    final useCase = DeleteNoteUseCase(repository);

    state = await AsyncValue.guard(() async {
      await useCase.call(sessionId, noteId);
      appLogger.info('note_delete: action succeeded');
      appLogger.debug(AnalyticsEvents.noteDeleted);
    });
  }

  String _errorTypeLabel(Object? error) {
    return switch (error) {
      NoteFileTooLarge() => 'file_too_large',
      NoteUnsupportedMimeType() => 'unsupported_mime',
      NoteSessionCapReached() => 'cap_reached',
      _ => 'upload_failed',
    };
  }
}
