// Golden tests for FilesTab (ADR 0008).
//
// Covers two states at two text scales (1.0, 1.5) with locale fixed to 'th':
//   - empty state
//   - data state with 3 notes
//
// Regenerate with:
//   flutter test --update-goldens test/features/note_sharing/presentation/goldens/files_tab_golden_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_actions_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart';
import 'package:mobile/features/note_sharing/presentation/providers/notes_provider.dart';
import 'package:mobile/features/note_sharing/presentation/widgets/files_tab.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ── Fake notifier ─────────────────────────────────────────────────────────────

class _FakeNoteActionsNotifier extends NoteActionsNotifier {
  @override
  FutureOr<void> build(String sessionId) {}

  @override
  Future<void> upload(_) async {}

  @override
  Future<void> delete(String noteId) async {}
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
  required List<NoteEntity> notes,
}) {
  const sessionId = 'sess-golden';

  return ProviderScope(
    overrides: [
      noteSharingEnabledProvider.overrideWithValue(true),
      notesProvider(sessionId).overrideWith((_) => Stream.value(notes)),
      noteActionsNotifierProvider(
        sessionId,
      ).overrideWith(() => _FakeNoteActionsNotifier()),
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
        child: const Scaffold(
          body: FilesTab(
            sessionId: sessionId,
            currentUserId: 'uid-current',
            hostUid: 'uid-host',
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FilesTab golden — empty state', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildGolden(textScale: 1.0, notes: []));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(FilesTab),
          matchesGoldenFile('files_tab_empty_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildGolden(textScale: 1.5, notes: []));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(FilesTab),
          matchesGoldenFile('files_tab_empty_scale_1.5_th.png'),
        );
      });
    });
  });

  group('FilesTab golden — data state (3 notes)', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(3, _note);
        await tester.pumpWidget(_buildGolden(textScale: 1.0, notes: notes));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(FilesTab),
          matchesGoldenFile('files_tab_data_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        final notes = List.generate(3, _note);
        await tester.pumpWidget(_buildGolden(textScale: 1.5, notes: notes));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(FilesTab),
          matchesGoldenFile('files_tab_data_scale_1.5_th.png'),
        );
      });
    });
  });
}
