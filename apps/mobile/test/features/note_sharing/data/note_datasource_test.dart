// Unit tests for NoteDatasource (ADR 0008 + ADR 0012 amendments).
//
// Uses fake_cloud_firestore. Firebase Storage is mocked (mocktail) because:
//   - no fake_firebase_storage in dev deps
//   - writeNoteBatch does NOT call _storage — only deleteNoteBatch/uploadFile do
//   - injecting a mock Storage prevents FirebaseStorage.instance from being
//     called (which requires a real Firebase app).
//
// Covers:
//   - writeNoteBatch: file_shared message written with senderDisplayName
//   - writeNoteBatch: file_shared message written with downloadUrl
//   - writeNoteBatch: groupChats fan-out written for each session member
//   - writeNoteBatch: note document and noteCount increment also committed

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/data/datasources/note_datasource.dart';
import 'package:mobile/features/note_sharing/data/models/note_model.dart';
import 'package:mocktail/mocktail.dart';

// FirebaseStorage is not @sealed so this mock is safe.
class _MockFirebaseStorage extends Mock implements FirebaseStorage {}

// ── Helper ────────────────────────────────────────────────────────────────────

NoteModel _stubNoteModel({
  String noteId = 'note-1',
  String uploaderUid = 'uid-uploader',
  String uploaderDisplayName = 'Alice',
  String fileName = 'report.pdf',
  String downloadUrl = 'https://storage.example.com/report.pdf',
}) => NoteModel(
  noteId: noteId,
  uploaderUid: uploaderUid,
  uploaderDisplayName: uploaderDisplayName,
  fileName: fileName,
  mimeType: 'application/pdf',
  sizeBytes: 1024,
  storageRef: 'sessions/session-1/notes/$noteId',
  downloadUrl: downloadUrl,
  uploadedAt: DateTime(2026, 5, 1, 10),
);

/// Pre-creates the session document so noteCount increment succeeds.
Future<void> _createSessionDoc(
  FakeFirebaseFirestore fakeFirestore,
  String sessionId, {
  List<String> memberUids = const ['uid-uploader', 'uid-member'],
}) async {
  await fakeFirestore.doc('sessions/$sessionId').set({
    'title': 'Study Group',
    'memberUids': memberUids,
    'noteCount': 0,
    'hostUid': 'uid-uploader',
    'status': 'active',
    'scheduledAt': Timestamp.now(),
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });
}

void main() {
  group('writeNoteBatch', () {
    test(
      'file_shared message is written with senderDisplayName field',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await _createSessionDoc(fakeFirestore, 'session-1');
        final datasource = NoteDatasource(
          firestore: fakeFirestore,
          storage: _MockFirebaseStorage(),
        );
        final model = _stubNoteModel();

        await datasource.writeNoteBatch(
          'session-1',
          model,
          memberUids: const ['uid-uploader', 'uid-member'],
          sessionTitle: 'Study Group',
        );

        final msgs = await fakeFirestore
            .collection('sessions/session-1/messages')
            .get();
        expect(msgs.docs, hasLength(1));
        final data = msgs.docs.first.data();
        expect(data['type'], 'file_shared');
        expect(data['senderDisplayName'], 'Alice');
      },
    );

    test('file_shared message is written with downloadUrl field', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await _createSessionDoc(fakeFirestore, 'session-1');
      final datasource = NoteDatasource(
        firestore: fakeFirestore,
        storage: _MockFirebaseStorage(),
      );
      final model = _stubNoteModel();

      await datasource.writeNoteBatch(
        'session-1',
        model,
        memberUids: const ['uid-uploader'],
        sessionTitle: 'Study Group',
      );

      final msgs = await fakeFirestore
          .collection('sessions/session-1/messages')
          .get();
      final data = msgs.docs.first.data();
      expect(data['downloadUrl'], 'https://storage.example.com/report.pdf');
    });

    test('file_shared message carries fileName and noteId fields', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await _createSessionDoc(fakeFirestore, 'session-1');
      final datasource = NoteDatasource(
        firestore: fakeFirestore,
        storage: _MockFirebaseStorage(),
      );
      final model = _stubNoteModel(noteId: 'note-42', fileName: 'slides.pptx');

      await datasource.writeNoteBatch(
        'session-1',
        model,
        memberUids: const ['uid-uploader'],
        sessionTitle: 'Study Group',
      );

      final msgs = await fakeFirestore
          .collection('sessions/session-1/messages')
          .get();
      final data = msgs.docs.first.data();
      expect(data['fileName'], 'slides.pptx');
      expect(data['noteId'], 'note-42');
      expect(data['senderUid'], 'uid-uploader');
    });

    test('groupChats fan-out written for each session member', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      const memberUids = ['uid-uploader', 'uid-member-a', 'uid-member-b'];
      await _createSessionDoc(
        fakeFirestore,
        'session-1',
        memberUids: memberUids,
      );
      final datasource = NoteDatasource(
        firestore: fakeFirestore,
        storage: _MockFirebaseStorage(),
      );

      await datasource.writeNoteBatch(
        'session-1',
        _stubNoteModel(),
        memberUids: memberUids,
        sessionTitle: 'Study Group',
      );

      for (final uid in memberUids) {
        final snap = await fakeFirestore
            .doc('users/$uid/groupChats/session-1')
            .get();
        expect(
          snap.exists,
          isTrue,
          reason: 'groupChats doc missing for uid=$uid',
        );
      }
    });

    test(
      "uploader's groupChats doc has unreadCount == 0, others == 1",
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await _createSessionDoc(fakeFirestore, 'session-1');
        final datasource = NoteDatasource(
          firestore: fakeFirestore,
          storage: _MockFirebaseStorage(),
        );

        await datasource.writeNoteBatch(
          'session-1',
          _stubNoteModel(),
          memberUids: const ['uid-uploader', 'uid-member'],
          sessionTitle: 'Study Group',
        );

        final uploaderSnap = await fakeFirestore
            .doc('users/uid-uploader/groupChats/session-1')
            .get();
        expect(uploaderSnap.data()!['unreadCount'], 0);

        final memberSnap = await fakeFirestore
            .doc('users/uid-member/groupChats/session-1')
            .get();
        expect(memberSnap.data()!['unreadCount'], 1);
      },
    );

    test('note document is written at sessions/{sid}/notes/{noteId}', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await _createSessionDoc(fakeFirestore, 'session-1');
      final datasource = NoteDatasource(
        firestore: fakeFirestore,
        storage: _MockFirebaseStorage(),
      );

      await datasource.writeNoteBatch(
        'session-1',
        _stubNoteModel(noteId: 'note-xyz'),
        memberUids: const ['uid-uploader'],
        sessionTitle: 'Study Group',
      );

      final noteSnap = await fakeFirestore
          .doc('sessions/session-1/notes/note-xyz')
          .get();
      expect(noteSnap.exists, isTrue);
      expect(noteSnap.data()!['noteId'], 'note-xyz');
    });

    test('noteCount is incremented on the session document', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await _createSessionDoc(fakeFirestore, 'session-1');
      final datasource = NoteDatasource(
        firestore: fakeFirestore,
        storage: _MockFirebaseStorage(),
      );

      await datasource.writeNoteBatch(
        'session-1',
        _stubNoteModel(),
        memberUids: const ['uid-uploader'],
        sessionTitle: 'Study Group',
      );

      final sessionSnap = await fakeFirestore.doc('sessions/session-1').get();
      expect(sessionSnap.data()!['noteCount'], 1);
    });
  });
}
