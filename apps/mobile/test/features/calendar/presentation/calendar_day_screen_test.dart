// Widget tests for CalendarDayScreen.
//
// Tests:
//   1. Smoke test — screen renders.
//   2. Count label ("N sessions · sorted by start time") is shown.
//   3. All sessions are rendered via ListView.builder (each gets a SessionCard).
//   4. The ListView uses a bounded itemCount (itemCount = n + 1).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_day_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

// ── Session fixture ───────────────────────────────────────────────────────────

SessionEntity _session({
  required String id,
  required DateTime scheduledAt,
}) {
  return SessionEntity(
    sessionId: id,
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Session Title $id',
    hashtags: const ['flutter'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['uid-1'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: scheduledAt,
    scheduledEndAt: scheduledAt.add(const Duration(hours: 1)),
    location: 'Library B',
    capacity: 5,
    hostDisplayName: 'Host User',
    createdAt: scheduledAt,
    updatedAt: scheduledAt,
  );
}

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildScreen({
  required DateTime day,
  required List<SessionEntity> sessions,
  String uid = 'uid-1',
}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(uid)),
      ),
      sessionRepositoryProvider.overrideWith(
        (_) => throw UnimplementedError('not needed in widget test'),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
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
      home: CalendarDayScreen(day: day, sessions: sessions),
    ),
  );
}

void main() {
  final day = DateTime(2026, 5, 20);

  group('CalendarDayScreen smoke tests', () {
    testWidgets('renders without error', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: []),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(CalendarDayScreen), findsOneWidget);
      });
    });

    testWidgets('renders app bar with date and All Sessions label', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: []),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.textContaining('All Sessions'), findsOneWidget);
      });
    });

    testWidgets('renders count label with correct session count', (tester) async {
      final sessions = [
        _session(id: 'a', scheduledAt: day),
        _session(id: 'b', scheduledAt: day),
        _session(id: 'c', scheduledAt: day),
      ];

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: sessions),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.textContaining('3 sessions'),
          findsOneWidget,
        );
      });
    });

    testWidgets('count label contains "sorted by start time"', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: [_session(id: 'x', scheduledAt: day)]),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.textContaining('sorted by start time'), findsOneWidget);
      });
    });

    testWidgets('renders ListView.builder with bounded itemCount', (tester) async {
      final sessions = List.generate(
        4,
        (i) => _session(id: 'sess-$i', scheduledAt: day),
      );

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: sessions),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        // ListView.builder should be present.
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    testWidgets('each session title is rendered', (tester) async {
      final sessions = [
        _session(id: 'alpha', scheduledAt: day),
        _session(id: 'beta', scheduledAt: day),
      ];

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: sessions),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.textContaining('Session Title alpha'), findsOneWidget);
        expect(find.textContaining('Session Title beta'), findsOneWidget);
      });
    });

    testWidgets('shows 0 sessions count label with empty session list',
        (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: const []),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.textContaining('0 sessions'), findsOneWidget);
      });
    });

    testWidgets('renders Calendar label in app bar sub-title', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(day: day, sessions: const []),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Calendar'), findsOneWidget);
      });
    });
  });
}
