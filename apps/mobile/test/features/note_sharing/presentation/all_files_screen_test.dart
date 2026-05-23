// Widget tests for AllFilesScreen (ADR 0008).
//
// Covers:
//   - loading state → CircularProgressIndicator
//   - error state → error text shown (skipError:true means no crash on error with no prior data)
//   - empty notes list → no NoteTile widgets rendered
//   - notes list rendered → file names visible
//   - upload FAB visible and labelled "Upload file"
//   - "Load more" button visible when hasMore = true
//   - "Load more" button hidden when hasMore = false
//
// AllFilesScreen pops when feature flag is false, so flag is always true here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_actions_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/paginated_notes_provider.dart';
import 'package:mobile/features/note_sharing/presentation/screens/all_files_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _FakeNoteActionsNotifier extends NoteActionsNotifier {
  @override
  FutureOr<void> build(String sessionId) {}

  @override
  Future<void> upload(_) async {}

  @override
  Future<void> delete(String noteId) async {}
}

class _FakePaginatedNotifier extends PaginatedNotesNotifier {
  _FakePaginatedNotifier(this._state);
  final PaginatedNotesState _state;

  @override
  Future<PaginatedNotesState> build(String sessionId) async => _state;

  @override
  Future<void> fetchNextPage() async {}

  @override
  Future<void> refresh() async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

NoteEntity _note(String noteId) => NoteEntity(
  noteId: noteId,
  uploaderUid: 'uid-uploader',
  uploaderDisplayName: 'Alice',
  fileName: '$noteId.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 1024,
  storageRef: 'sessions/sess-1/notes/$noteId',
  downloadUrl: 'https://example.com/$noteId',
  uploadedAt: DateTime(2026, 5, 23),
);

Widget _buildScreen({
  PaginatedNotesState? paginatedState,
  bool paginatedLoading = false,
  bool paginatedError = false,
  String currentUserId = 'uid-current',
  String hostUid = 'uid-host',
  String sessionId = 'sess-1',
}) {
  final defaultState =
      paginatedState ?? (notes: const <NoteEntity>[], hasMore: false);

  return ProviderScope(
    overrides: [
      noteSharingEnabledProvider.overrideWithValue(true),
      noteActionsNotifierProvider(
        sessionId,
      ).overrideWith(() => _FakeNoteActionsNotifier()),
      paginatedNotesNotifierProvider(sessionId).overrideWith(() {
        if (paginatedLoading) {
          return _LoadingPaginatedNotifier();
        }
        if (paginatedError) {
          return _ErrorPaginatedNotifier();
        }
        return _FakePaginatedNotifier(defaultState);
      }),
    ],
    child: MaterialApp(
      home: AllFilesScreen(
        sessionId: sessionId,
        currentUserId: currentUserId,
        hostUid: hostUid,
      ),
    ),
  );
}

// Notifier that stays loading forever (uses a Completer that never completes).
class _LoadingPaginatedNotifier extends PaginatedNotesNotifier {
  @override
  Future<PaginatedNotesState> build(String sessionId) =>
      Completer<PaginatedNotesState>().future;
}

// Notifier that errors immediately.
class _ErrorPaginatedNotifier extends PaginatedNotesNotifier {
  @override
  Future<PaginatedNotesState> build(String sessionId) async {
    throw Exception('Firestore error');
  }
}

void main() {
  group('AllFilesScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(paginatedLoading: true));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });

  group('AllFilesScreen — error state', () {
    testWidgets('no exception thrown when provider errors (skipError:true)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(paginatedError: true));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // skipError:true — no crash; loading spinner shown until data arrives.
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('AllFilesScreen — empty notes list', () {
    testWidgets('renders scaffold with app bar "All Files"', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: [], hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.text('All Files'), findsOneWidget);
      });
    });

    testWidgets('no note tiles when notes list is empty', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: [], hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        // No file name texts from notes.
        expect(find.textContaining('.pdf'), findsNothing);
      });
    });

    testWidgets('"Load more" button absent when hasMore = false and empty', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: [], hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.text('Load more'), findsNothing);
      });
    });
  });

  group('AllFilesScreen — notes list rendered', () {
    testWidgets('renders file names for each note', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(3, (i) => _note('note-$i'));
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: notes, hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        for (var i = 0; i < 3; i++) {
          expect(find.text('note-$i.pdf'), findsOneWidget);
        }
      });
    });

    testWidgets('"Load more" button visible when hasMore = true', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(5, (i) => _note('note-$i'));
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: notes, hasMore: true)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.text('Load more'), findsOneWidget);
      });
    });

    testWidgets('"Load more" button absent when hasMore = false', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(5, (i) => _note('note-$i'));
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: notes, hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.text('Load more'), findsNothing);
      });
    });

    testWidgets('"Load more" button has Semantics label "Load more files"', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(2, (i) => _note('note-$i'));
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: notes, hasMore: true)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.bySemanticsLabel('Load more files'), findsOneWidget);
      });
    });
  });

  group('AllFilesScreen — upload FAB', () {
    testWidgets('upload FAB is visible', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: [], hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });
    });

    testWidgets('upload FAB has Semantics label "Upload file"', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(paginatedState: (notes: [], hasMore: false)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.bySemanticsLabel('Upload file'), findsOneWidget);
      });
    });
  });

  group('AllFilesScreen — delete button visibility', () {
    testWidgets('delete button hidden for non-owner non-host', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = [
          NoteEntity(
            noteId: 'note-0',
            uploaderUid: 'uid-uploader',
            uploaderDisplayName: 'Alice',
            fileName: 'note-0.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 1024,
            storageRef: 'sessions/sess-1/notes/note-0',
            downloadUrl: 'https://example.com/note-0',
            uploadedAt: DateTime(2026, 5, 23),
          ),
        ];
        await tester.pumpWidget(
          _buildScreen(
            paginatedState: (notes: notes, hasMore: false),
            currentUserId: 'uid-bystander',
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.bySemanticsLabel('Delete note-0.pdf'), findsNothing);
      });
    });

    testWidgets('delete button visible for file owner', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = [
          NoteEntity(
            noteId: 'note-0',
            uploaderUid: 'uid-owner',
            uploaderDisplayName: 'Alice',
            fileName: 'note-0.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 1024,
            storageRef: 'sessions/sess-1/notes/note-0',
            downloadUrl: 'https://example.com/note-0',
            uploadedAt: DateTime(2026, 5, 23),
          ),
        ];
        await tester.pumpWidget(
          _buildScreen(
            paginatedState: (notes: notes, hasMore: false),
            currentUserId: 'uid-owner',
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.bySemanticsLabel('Delete note-0.pdf'), findsOneWidget);
      });
    });
  });
}
