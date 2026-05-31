import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/errors/note_error.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/storage_paths.dart';
import 'package:mobile/features/note_sharing/data/datasources/note_datasource.dart';
import 'package:mobile/features/note_sharing/data/models/note_model.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';

/// Implements [NoteRepository] against Firestore and Firebase Storage
/// (ADR 0008 sub-decision 2).
///
/// Upload sequence:
///   (a) Upload bytes to Storage via [NoteDatasource.uploadFile].
///   (b) Commit [WriteBatch] via [NoteDatasource.writeNoteBatch].
///   (c) On batch failure: delete orphan Storage object and throw
///       [NoteError.uploadFailed].
class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({
    required NoteDatasource datasource,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _datasource = datasource,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final NoteDatasource _datasource;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ── Watch ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<NoteEntity>> watchNotes(String sessionId) {
    return _datasource
        .watchNotes(sessionId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  @override
  Future<void> uploadNote(String sessionId, NoteUploadParams params) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const NoteUploadFailed('unauthenticated');
    }
    final uploaderUid = currentUser.uid;

    final uploaderDisplayName = _auth.currentUser?.displayName ?? '';

    // Auto-generate the Firestore document ID upfront so the Storage path
    // and the Firestore document share the same noteId.
    final noteRef = _firestore
        .collection(FirestorePaths.sessionNotesCollection(sessionId))
        .doc();
    final noteId = noteRef.id;
    final storageRef = StoragePaths.sessionNote(sessionId, noteId);

    // (b) Upload bytes to Storage.
    final downloadUrl = await _datasource.uploadFile(
      sessionId,
      noteId,
      params.bytes,
      params.mimeType,
      params.fileName,
    );

    // (c) Commit WriteBatch (note document + noteCount increment).
    final model = NoteModel(
      noteId: noteId,
      uploaderUid: uploaderUid,
      uploaderDisplayName: uploaderDisplayName,
      fileName: params.fileName,
      mimeType: params.mimeType,
      sizeBytes: params.sizeBytes,
      storageRef: storageRef,
      downloadUrl: downloadUrl,
      uploadedAt: DateTime.now(),
    );

    // Fetch session metadata needed for the file_shared message fan-out (ADR 0012).
    final sessionSnap = await _firestore
        .doc(FirestorePaths.sessionDoc(sessionId))
        .get();
    final sessionData = sessionSnap.data();
    final memberUids =
        (sessionData?['memberUids'] as List<dynamic>?)?.cast<String>() ??
        <String>[];
    final sessionTitle = (sessionData?['title'] as String?) ?? '';

    try {
      await _datasource.writeNoteBatch(
        sessionId,
        model,
        memberUids: memberUids,
        sessionTitle: sessionTitle,
      );
    } catch (e, st) {
      // (d) WriteBatch failed — delete orphan Storage object.
      appLogger.error(
        'note_upload: WriteBatch failed; deleting orphan noteId=$noteId',
        exception: e,
        stackTrace: st,
      );

      try {
        await _datasource.deleteStorageFile(storageRef);
      } catch (cleanupError, cleanupSt) {
        appLogger.error(
          'note_upload: orphan Storage delete failed noteId=$noteId',
          exception: cleanupError,
          stackTrace: cleanupSt,
        );
        if (!kIsWeb) {
          await FirebaseCrashlytics.instance.recordError(
            cleanupError,
            cleanupSt,
            reason: 'note_upload orphan cleanup failed',
          );
        }
      }

      if (e is FirebaseException && e.code == 'permission-denied') {
        // permission-denied from WriteBatch has multiple causes: non-member,
        // uploaderUid mismatch, timestamp mismatch, or session cap exceeded.
        // We cannot distinguish them by error code alone, so surface the
        // authoritative authorization failure rather than the cap variant.
        throw const NotePermissionDenied();
      }
      throw NoteUploadFailed(e.runtimeType.toString());
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteNote(String sessionId, String noteId) async {
    // Fetch the note document to obtain storageRef before deleting.
    final noteSnap = await _firestore
        .doc(FirestorePaths.sessionNoteDoc(sessionId, noteId))
        .get();

    final storageRef =
        noteSnap.data()?['storageRef'] as String? ??
        StoragePaths.sessionNote(sessionId, noteId);

    try {
      await _datasource.deleteNoteBatch(sessionId, noteId, storageRef);
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        throw const NotePermissionDenied();
      }
      appLogger.error(
        'note_delete: deleteNoteBatch failed noteId=$noteId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      throw NoteDeleteFailed(e.code);
    } catch (e, st) {
      appLogger.error(
        'note_delete: unexpected error noteId=$noteId',
        exception: e,
        stackTrace: st,
      );
      throw NoteDeleteFailed(e.runtimeType.toString());
    }
  }

  // ── Paginated fetch ────────────────────────────────────────────────────────

  @override
  Future<List<NoteEntity>> fetchNotesPage(
    String sessionId, {
    int limit = 20,
    DateTime? startAfter,
  }) async {
    final models = await _datasource.fetchNotesPage(
      sessionId,
      limit: limit,
      startAfter: startAfter,
    );
    return models.map((m) => m.toEntity()).toList();
  }
}
