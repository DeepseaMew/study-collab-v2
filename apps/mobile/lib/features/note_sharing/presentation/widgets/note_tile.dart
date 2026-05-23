import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/presentation/widgets/web_file_downloader.dart';
import 'package:url_launcher/url_launcher.dart';

/// A single list tile representing a shared note file (ADR 0008).
///
/// - Image MIME types render a [CachedNetworkImage] thumbnail in the leading
///   slot. All other MIME types show a category icon.
/// - Delete button is visible only when [currentUserId] == [note.uploaderUid]
///   or [currentUserId] == [hostUid].
/// - Tapping the tile launches the file via [url_launcher].
/// - Minimum tile height: 56 dp; delete button minimum touch target: 44 × 44 dp.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.currentUserId,
    required this.hostUid,
    required this.onDelete,
  });

  final NoteEntity note;
  final String currentUserId;
  final String hostUid;

  /// Called when the delete button is tapped.
  final VoidCallback onDelete;

  bool get _canDelete =>
      currentUserId == note.uploaderUid || currentUserId == hostUid;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openFile,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _LeadingWidget(
                mimeType: note.mimeType,
                downloadUrl: note.downloadUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatSize(note.sizeBytes)} · '
                      '${_relativeTime(note.uploadedAt)} · '
                      '${note.uploaderDisplayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        // Contrast ratio ≥ 4.5:1 against white/surface.
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Download ${note.fileName}',
                button: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.download_outlined,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                    onPressed: _downloadFile,
                  ),
                ),
              ),
              if (_canDelete)
                Semantics(
                  label: 'Delete ${note.fileName}',
                  button: true,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                      onPressed: onDelete,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile() async {
    if (kIsWeb) {
      downloadFileOnWeb(note.downloadUrl, note.fileName);
      appLogger.debug(AnalyticsEvents.noteFileOpened);
      return;
    }
    final uri = Uri.tryParse(note.downloadUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      appLogger.debug(AnalyticsEvents.noteFileOpened);
    } catch (e, st) {
      appLogger.error(
        'note_tile: failed to download file',
        exception: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _openFile() async {
    final uri = Uri.tryParse(note.downloadUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      appLogger.info('note_file_opened');
      appLogger.debug(AnalyticsEvents.noteFileOpened);
    } catch (e, st) {
      appLogger.error(
        'note_tile: failed to open file',
        exception: e,
        stackTrace: st,
      );
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Leading widget ─────────────────────────────────────────────────────────────

class _LeadingWidget extends StatelessWidget {
  const _LeadingWidget({required this.mimeType, required this.downloadUrl});

  final String mimeType;
  final String downloadUrl;

  static const Set<String> _imageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  @override
  Widget build(BuildContext context) {
    if (_imageMimeTypes.contains(mimeType)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: downloadUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 56,
            height: 56,
            color: const Color(0xFFF3F4F6),
            child: const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 56,
            height: 56,
            color: const Color(0xFFF3F4F6),
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        _iconForMimeType(mimeType),
        color: const Color(0xFF6B7280),
        size: 28,
      ),
    );
  }

  static IconData _iconForMimeType(String mimeType) {
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') ||
        mimeType.contains('document') ||
        mimeType == 'text/plain') {
      return Icons.description_outlined;
    }
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('7z')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
