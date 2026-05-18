// Widget tests for MySessionsScreen.
//
// Smoke test: screen renders without exception and shows the three tabs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/hosted_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/screens/my_sessions_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:network_image_mock/network_image_mock.dart';

UserEntity _fakeUser() => const UserEntity(
      uid: 'user-1',
      displayName: 'Test User',
      fullName: 'Test Full',
      email: 'user1@mail.kmutt.ac.th',
      hasHostedBefore: false,
      studentYear: 2,
      academicLevel: 'undergraduate',
      faculty: 'Engineering',
      profileScore: 0.0,
    );

SessionEntity _session(String id, String status) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: 'user-1',
    hostFaculty: 'Engineering',
    title: 'Session $id',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 1,
    visibility: 'public',
    memberUids: const ['user-1'],
    noteCount: 0,
    status: status,
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Test User',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen({
  AsyncValue<List<SessionEntity>> upcoming =
      const AsyncValue.data(<SessionEntity>[]),
  AsyncValue<List<SessionEntity>> completed =
      const AsyncValue.data(<SessionEntity>[]),
  AsyncValue<List<SessionEntity>> hosted =
      const AsyncValue.data(<SessionEntity>[]),
  UserEntity? user,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (_) => Stream.value(user ?? _fakeUser()),
      ),
      upcomingSessionsProvider('user-1').overrideWith(
        (_) => upcoming.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      completedSessionsProvider('user-1').overrideWith(
        (_) => completed.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      hostedSessionsProvider('user-1').overrideWith(
        (_) => hosted.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
    ],
    child: const MaterialApp(home: MySessionsScreen()),
  );
}

void main() {
  testWidgets('MySessionsScreen smoke test — renders without exception', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets('MySessionsScreen — shows "My Sessions" title', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // "My Sessions" appears as the AppBar title and as the third tab label.
      expect(find.text('My Sessions'), findsWidgets);
    });
  });

  testWidgets('MySessionsScreen — three tabs are present', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('My Sessions'), findsWidgets);
    });
  });

  testWidgets(
      'MySessionsScreen — search bar is present', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.widgetWithText(TextField, 'Search sessions...'), findsOneWidget);
    });
  });

  testWidgets(
      'MySessionsScreen — empty Upcoming tab shows empty state message', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('No upcoming sessions.'), findsOneWidget);
    });
  });

  testWidgets(
      'MySessionsScreen — Upcoming tab renders session cards when data available',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          upcoming: AsyncValue.data([_session('s1', 'scheduled')]),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Session s1'), findsOneWidget);
    });
  });

  testWidgets('MySessionsScreen — unauthenticated state shows sign-in prompt',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((_) => Stream.value(null)),
          ],
          child: const MaterialApp(home: MySessionsScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.text('Sign in to see your sessions.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
      'MySessionsScreen — search filters sessions by title', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          upcoming: AsyncValue.data([
            _session('algorithms', 'scheduled'),
            _session('calculus', 'scheduled'),
          ]),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.enterText(
        find.widgetWithText(TextField, 'Search sessions...'),
        'algorithms',
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Session algorithms'), findsOneWidget);
      expect(find.text('Session calculus'), findsNothing);
    });
  });
}
