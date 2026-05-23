import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/storage_paths.dart';
import 'package:mobile/features/note_sharing/data/models/note_model.dart';

/// Low-level data operations for note-sharing (ADR 0008).
///
/// All Firestore path strings come from [FirestorePaths].
/// All Storage path strings come from [StoragePaths].
/// No domain types cross this boundary — callers in [NoteRepositoryImpl]
/// handle model-to-entity conversion.
class NoteDatasource {
  NoteDatasource({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // ── Watch ──────────────────────────────────────────────────────────────────

  /// Streams all notes for [sessionId] ordered by `uploadedAt` descending.
  /// Uses Index 7 from ADR 0001.
  Stream<List<NoteModel>> watchNotes(String sessionId) {
    return _firestore
        .collection(FirestorePaths.sessionNotesCollection(sessionId))
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NoteModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  /// Uploads [bytes] to Storage at `sessions/{sessionId}/notes/{noteId}`.
  ///
  /// Returns the download URL on success.
  /// Logs progress at debug level.
  /// Records a non-fatal Crashlytics event on [FirebaseException].
  Future<String> uploadFile(
    String sessionId,
    String noteId,
    Uint8List bytes,
    String mimeType,
    String fileName,
  ) async {
    appLogger.debug(
      'note_upload: starting upload sessionId=$sessionId noteId=$noteId',
    );

    final ref = _storage.ref(StoragePaths.sessionNote(sessionId, noteId));
    try {
      final task = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType,
          contentDisposition:
              "inline; filename*=UTF-8''${Uri.encodeComponent(fileName)}",
        ),
      );
      final downloadUrl = await task.ref.getDownloadURL();
      appLogger.info(
        'note_upload: upload complete sessionId=$sessionId noteId=$noteId',
      );
      return downloadUrl;
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'note_upload: Storage upload failed sessionId=$sessionId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'note_upload Storage upload failed',
        );
      }
      rethrow;
    }
  }

  /// Commits a [WriteBatch]: creates the note document and increments
  /// `noteCount` by 1 on the parent session document.
  Future<void> writeNoteBatch(String sessionId, NoteModel model) async {
    final batch = _firestore.batch();

    final noteRef = _firestore.doc(
      FirestorePaths.sessionNoteDoc(sessionId, model.noteId),
    );
    // Override uploadedAt with FieldValue.serverTimestamp() so the Firestore
    // rule `uploadedAt == request.time` is satisfied. Client-side DateTime.now()
    // never matches the server request timestamp.
    batch.set(noteRef, {
      ...model.toJson(),
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    final sessionRef = _firestore.doc(FirestorePaths.sessionDoc(sessionId));
    batch.update(sessionRef, {'noteCount': FieldValue.increment(1)});

    await batch.commit();
  }

  /// Commits a [WriteBatch]: deletes the note document and decrements
  /// `noteCount` by 1; on success deletes the Storage object.
  ///
  /// If the Storage delete fails after a successful Firestore batch:
  /// logs at error level, records a non-fatal Crashlytics event,
  /// and does NOT re-throw (note is already gone from Firestore).
  Future<void> deleteNoteBatch(
    String sessionId,
    String noteId,
    String storageRef,
  ) async {
    final batch = _firestore.batch();

    final noteRef = _firestore.doc(
      FirestorePaths.sessionNoteDoc(sessionId, noteId),
    );
    batch.delete(noteRef);

    final sessionRef = _firestore.doc(FirestorePaths.sessionDoc(sessionId));
    batch.update(sessionRef, {'noteCount': FieldValue.increment(-1)});

    await batch.commit();

    appLogger.info(
      'note_delete: Firestore batch committed noteId=$noteId sessionId=$sessionId',
    );

    try {
      await _storage.ref(storageRef).delete();
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'note_delete: Storage delete failed noteId=$noteId errorCode=${e.code}',
        exception: e,
        stackTrace: st,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'note_delete Storage delete failed after Firestore batch',
        );
      }
      // Do not re-throw: Firestore batch succeeded; Storage orphan is accepted
      // at MVP per ADR 0008 risk acceptance section.
    }
  }

  /// Deletes the orphan Storage object when a [WriteBatch] fails after a
  /// successful Storage upload during note creation.
  Future<void> deleteStorageFile(String storageRef) async {
    await _storage.ref(storageRef).delete();
  }

  // ── Paginated fetch ────────────────────────────────────────────────────────

  /// Fetches a page of notes ordered by `uploadedAt` descending.
  ///
  /// Applies `.startAfter([Timestamp.fromDate(startAfter)])` when
  /// [startAfter] is non-null.
  Future<List<NoteModel>> fetchNotesPage(
    String sessionId, {
    int limit = 20,
    DateTime? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.sessionNotesCollection(sessionId))
        .orderBy('uploadedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return [];

    return snapshot.docs.map((doc) => NoteModel.fromJson(doc.data())).toList();
  }
}
