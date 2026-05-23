// Golden tests for AllFilesScreen (ADR 0008).
//
// Covers two states at two text scales (1.0, 1.5) with locale fixed to 'th':
//   - empty state
//   - data state with 3 notes
//
// Regenerate with:
//   flutter test --update-goldens test/features/note_sharing/presentation/goldens/all_files_screen_golden_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_actions_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/paginated_notes_provider.dart';
import 'package:mobile/features/note_sharing/presentation/screens/all_files_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
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

NoteEntity _note(int index) => NoteEntity(
  noteId: 'note-$index',
  uploaderUid: 'uid-uploader',
  uploaderDisplayName: 'Alice',
  fileName: 'lecture_$index.pdf',
  mimeType: 'application/pdf',
  sizeBytes: (index + 1) * 512000,
  storageRef: 'sessions/sess-1/notes/note-$index',
  downloadUrl: 'https://example.com/note-$index',
  uploadedAt: DateTime(2026, 5, 23 - index),
);

Widget _buildGolden({
  required double textScale,
  required PaginatedNotesState paginatedState,
}) {
  const sessionId = 'sess-golden';

  return ProviderScope(
    overrides: [
      noteSharingEnabledProvider.overrideWithValue(true),
      noteActionsNotifierProvider(
        sessionId,
      ).overrideWith(() => _FakeNoteActionsNotifier()),
      paginatedNotesNotifierProvider(
        sessionId,
      ).overrideWith(() => _FakePaginatedNotifier(paginatedState)),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.background,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const AllFilesScreen(
          sessionId: sessionId,
          currentUserId: 'uid-current',
          hostUid: 'uid-host',
        ),
      ),
    ),
  );
}

void main() {
  group('AllFilesScreen golden — empty state', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildGolden(
            textScale: 1.0,
            paginatedState: (notes: [], hasMore: false),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(AllFilesScreen),
          matchesGoldenFile('all_files_screen_empty_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildGolden(
            textScale: 1.5,
            paginatedState: (notes: [], hasMore: false),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(AllFilesScreen),
          matchesGoldenFile('all_files_screen_empty_scale_1.5_th.png'),
        );
      });
    });
  });

  group('AllFilesScreen golden — data state (3 notes)', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(3, _note);
        await tester.pumpWidget(
          _buildGolden(
            textScale: 1.0,
            paginatedState: (notes: notes, hasMore: false),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(AllFilesScreen),
          matchesGoldenFile('all_files_screen_data_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(3, _note);
        await tester.pumpWidget(
          _buildGolden(
            textScale: 1.5,
            paginatedState: (notes: notes, hasMore: false),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(AllFilesScreen),
          matchesGoldenFile('all_files_screen_data_scale_1.5_th.png'),
        );
      });
    });
  });
}
