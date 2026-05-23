import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_actions_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/paginated_notes_provider.dart';
import 'package:mobile/features/note_sharing/presentation/widgets/note_tile.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Full paginated list of session files (ADR 0008).
///
/// Pushed from the "See All" button in [FilesTab].
/// Receives [sessionId], [currentUserId], and [hostUid] from GoRouter [extra].
class AllFilesScreen extends ConsumerWidget {
  const AllFilesScreen({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    required this.hostUid,
  });

  final String sessionId;
  final String currentUserId;
  final String hostUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Feature flag guard: pop and show snack if flag is off.
    final flagEnabled = ref.watch(noteSharingEnabledProvider);
    if (!flagEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Files are not available yet.'),
            ),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final paginatedAsync =
        ref.watch(paginatedNotesNotifierProvider(sessionId));
    final actionsState = ref.watch(noteActionsNotifierProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7143BF), AppColors.accent],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'All Files',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          paginatedAsync.when<Widget>(
            skipError: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) {
              appLogger.error(
                'AllFilesScreen: failed to load notes',
                exception: e,
                stackTrace: st,
                extra: {'sessionId': sessionId},
              );
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load files. Please try again.',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
            data: (PaginatedNotesState paginatedState) {
              final notes = paginatedState.notes;
              final hasMore = paginatedState.hasMore;

              return RefreshIndicator(
                onRefresh: () => ref
                    .read(paginatedNotesNotifierProvider(sessionId).notifier)
                    .refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: notes.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < notes.length) {
                      final note = notes[index];
                      return NoteTile(
                        note: note,
                        currentUserId: currentUserId,
                        hostUid: hostUid,
                        onDelete: () => ref
                            .read(
                              noteActionsNotifierProvider(sessionId).notifier,
                            )
                            .delete(note.noteId),
                      );
                    }

                    // Load more slot.
                    final isLoadingMore = paginatedAsync is AsyncLoading;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: isLoadingMore
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Semantics(
                              label: 'Load more files',
                              button: true,
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    side: const BorderSide(
                                      color: AppColors.accent,
                                    ),
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => ref
                                      .read(
                                        paginatedNotesNotifierProvider(
                                          sessionId,
                                        ).notifier,
                                      )
                                      .fetchNextPage(),
                                  child: const Text('Load more'),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              );
            },
          ),
          // Upload progress indicator.
          if (actionsState is AsyncLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Semantics(
        label: 'Upload file',
        button: true,
        child: FloatingActionButton(
          heroTag: 'all_files_fab_$sessionId',
          onPressed: () => _showUploadSheet(context, ref),
          backgroundColor: AppColors.accent,
          child: const Icon(Icons.upload_file_outlined, color: Colors.white),
        ),
      ),
    );
  }

  void _showUploadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Upload a File',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported: images (JPEG, PNG, GIF, WebP), PDF, Word, text, '
              'ZIP, RAR, 7z. Max 10 MB.',
              style: TextStyle(color: AppColors.hint, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Pick file'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickAndUpload(context, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      appLogger.warning('all_files_screen: FilePicker returned null bytes');
      return;
    }

    final mimeType = file.extension != null
        ? _mimeFromExtension(file.extension!)
        : 'application/octet-stream';

    final params = NoteUploadParams(
      fileName: file.name,
      mimeType: mimeType,
      sizeBytes: file.size,
      bytes: bytes,
    );

    await ref
        .read(noteActionsNotifierProvider(sessionId).notifier)
        .upload(params);

    final resultState = ref.read(noteActionsNotifierProvider(sessionId));
    if (resultState is AsyncError && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(resultState.error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      'rar' => 'application/x-rar-compressed',
      '7z' => 'application/x-7z-compressed',
      _ => 'application/octet-stream',
    };
  }

  static String _errorMessage(Object? error) {
    if (error == null) return 'Upload failed. Please try again.';
    final s = error.toString();
    if (s.contains('fileTooLarge')) return 'File exceeds the 10 MB limit.';
    if (s.contains('unsupportedMimeType')) {
      return 'File type is not supported.';
    }
    if (s.contains('sessionCapReached')) {
      return 'This session has reached the 50-file limit.';
    }
    if (s.contains('permissionDenied')) return 'Permission denied.';
    return 'Upload failed. Please try again.';
  }
}
