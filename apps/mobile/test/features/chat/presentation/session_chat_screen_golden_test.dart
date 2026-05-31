// Golden tests for SessionChatScreen (ADR 0012).
//
// One golden per text scale (1.0, 1.5), locale th_TH, fixed app theme.
// Goldens live in test/features/chat/presentation/goldens/.
//
// Regenerate with:
//   flutter test --update-goldens \
//     test/features/chat/presentation/session_chat_screen_golden_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/presentation/providers/session_chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/session_chat_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  @override
  String get uid => 'golden-me';

  @override
  String? get displayName => 'Golden Me';
}

// ── Stub data ──────────────────────────────────────────────────────────────────

const _myUid = 'golden-me';
const _sessionId = 'golden-session';

final _stubMessages = <SessionMessage>[
  SessionMessage(
    messageId: 'msg-1',
    type: 'text',
    senderUid: _myUid,
    senderDisplayName: 'Golden Me',
    sentAt: DateTime(2026, 5, 30, 14),
    text: 'สวัสดีทุกคน มาเริ่มเรียนกันเลย!',
  ),
  SessionMessage(
    messageId: 'msg-2',
    type: 'text',
    senderUid: 'golden-other',
    senderDisplayName: 'Alice Siriporn',
    sentAt: DateTime(2026, 5, 30, 14, 2),
    text: 'พร้อมแล้วค่ะ',
  ),
  SessionMessage(
    messageId: 'msg-3',
    type: 'file_shared',
    senderUid: 'golden-other',
    senderDisplayName: 'Alice Siriporn',
    sentAt: DateTime(2026, 5, 30, 14, 5),
    noteId: 'note-1',
    fileName: 'calculus_notes.pdf',
    downloadUrl: 'https://storage.example.com/calculus_notes.pdf',
  ),
];

SessionEntity _stubSession() => SessionEntity(
  sessionId: _sessionId,
  hostUid: _myUid,
  hostFaculty: 'Science',
  title: 'Calculus Study Group',
  hashtags: const ['calculus', 'math'],
  academicLevel: 'undergraduate',
  studentYear: 2,
  visibility: 'public',
  memberUids: const [_myUid, 'golden-other'],
  noteCount: 1,
  status: 'active',
  scheduledAt: DateTime(2026, 5, 30, 13),
  location: 'Library Room 3',
  capacity: 8,
  hostDisplayName: 'Golden Me',
  createdAt: DateTime(2026, 5, 28),
  updatedAt: DateTime(2026, 5, 30),
);

class _StubSessionChatActionsNotifier extends SessionChatActionsNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) async {
    state = const AsyncData(null);
  }

  @override
  Future<void> markSessionRead(String sessionId, String uid) async {}
}

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildGolden({required double textScale}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      sessionMessagesProvider(
        _sessionId,
      ).overrideWith((_) => Stream.value(_stubMessages)),
      sessionStreamProvider(
        _sessionId,
      ).overrideWith((_) => Stream.value(_stubSession())),
      sessionChatActionsNotifierProvider.overrideWith(
        () => _StubSessionChatActionsNotifier(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('th', 'TH'),
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
        child: const SessionChatScreen(sessionId: _sessionId),
      ),
    ),
  );
}

void main() {
  group('SessionChatScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SessionChatScreen),
        matchesGoldenFile('goldens/session_chat_screen_1_0.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(SessionChatScreen),
        matchesGoldenFile('goldens/session_chat_screen_1_5.png'),
      );
    });
  });
}
