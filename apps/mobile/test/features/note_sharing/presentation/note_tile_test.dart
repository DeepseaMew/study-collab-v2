// Widget tests for NoteTile (ADR 0008).
//
// Covers:
//   - image MIME shows CachedNetworkImage placeholder (via network_image_mock)
//   - non-image MIME shows a category icon (no CachedNetworkImage)
//   - fileName text rendered
//   - formatted sizeBytes text rendered
//   - uploaderDisplayName rendered
//   - delete button visible for file owner
//   - delete button visible for session host
//   - delete button hidden for non-owner non-host
//   - tapping delete calls onDelete callback
//   - Semantics label on delete button matches 'Delete ${note.fileName}'

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/presentation/widgets/note_tile.dart';
import 'package:network_image_mock/network_image_mock.dart';

NoteEntity _note({
  String noteId = 'note-1',
  String uploaderUid = 'uid-uploader',
  String uploaderDisplayName = 'Alice',
  String fileName = 'lecture.pdf',
  String mimeType = 'application/pdf',
  int sizeBytes = 4400000, // ~4.2 MB
  String downloadUrl = 'https://example.com/file.pdf',
}) => NoteEntity(
  noteId: noteId,
  uploaderUid: uploaderUid,
  uploaderDisplayName: uploaderDisplayName,
  fileName: fileName,
  mimeType: mimeType,
  sizeBytes: sizeBytes,
  storageRef: 'sessions/sess-1/notes/$noteId',
  downloadUrl: downloadUrl,
  uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
);

Widget _buildTile({
  required NoteEntity note,
  required String currentUserId,
  required String hostUid,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: NoteTile(
        note: note,
        currentUserId: currentUserId,
        hostUid: hostUid,
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  group('NoteTile — leading widget', () {
    testWidgets('image MIME type shows CachedNetworkImage', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(
          mimeType: 'image/jpeg',
          downloadUrl: 'https://example.com/photo.jpg',
        );
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });
    });

    testWidgets('image/png MIME type shows CachedNetworkImage', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(
          mimeType: 'image/png',
          downloadUrl: 'https://example.com/image.png',
        );
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });
    });

    testWidgets('non-image MIME (PDF) shows icon, not CachedNetworkImage', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final note = _note();
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      });
    });

    testWidgets('non-image MIME (zip) shows folder_zip icon', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(mimeType: 'application/zip');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
      });
    });

    testWidgets('non-image MIME (docx) shows description icon', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      });
    });
  });

  group('NoteTile — text content', () {
    testWidgets('renders fileName as title', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(fileName: 'my_lecture_notes.pdf');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('my_lecture_notes.pdf'), findsOneWidget);
      });
    });

    testWidgets('renders formatted sizeBytes in subtitle', (tester) async {
      await mockNetworkImagesFor(() async {
        // 4400000 bytes = ~4.2 MB
        final note = _note();
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        // Find text containing the MB size
        expect(find.textContaining('4.2 MB'), findsOneWidget);
      });
    });

    testWidgets('renders uploaderDisplayName in subtitle', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(uploaderDisplayName: 'Bob Smith');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('Bob Smith'), findsOneWidget);
      });
    });

    testWidgets('renders file size in KB for small files', (tester) async {
      await mockNetworkImagesFor(() async {
        final note = _note(sizeBytes: 2048); // 2.0 KB
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-other',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('2.0 KB'), findsOneWidget);
      });
    });
  });

  group('NoteTile — delete button visibility', () {
    testWidgets('delete button VISIBLE when currentUserId == uploaderUid', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final note = _note(
          uploaderUid: 'uid-owner',
          fileName: 'owner_file.pdf',
        );
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-owner', // owner
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.bySemanticsLabel('Delete owner_file.pdf'), findsOneWidget);
      });
    });

    testWidgets('delete button VISIBLE when currentUserId == hostUid', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final note = _note(fileName: 'some_file.pdf');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-host', // host
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.bySemanticsLabel('Delete some_file.pdf'), findsOneWidget);
      });
    });

    testWidgets('delete button HIDDEN for non-owner non-host user', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final note = _note(fileName: 'other_file.pdf');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-bystander', // neither owner nor host
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.bySemanticsLabel('Delete other_file.pdf'), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
    });
  });

  group('NoteTile — delete callback', () {
    testWidgets('tapping delete button calls onDelete callback', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        var deleteCalled = false;
        final note = _note(uploaderUid: 'uid-owner', fileName: 'to_delete.pdf');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-owner',
            hostUid: 'uid-host',
            onDelete: () => deleteCalled = true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.bySemanticsLabel('Delete to_delete.pdf'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(deleteCalled, isTrue);
      });
    });
  });

  group('NoteTile — semantics', () {
    testWidgets('delete button Semantics label includes filename', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final note = _note(uploaderUid: 'uid-owner', fileName: 'important.pdf');
        await tester.pumpWidget(
          _buildTile(
            note: note,
            currentUserId: 'uid-owner',
            hostUid: 'uid-host',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Delete important.pdf'),
        );
        expect(semantics.label, 'Delete important.pdf');
      });
    });
  });
}
