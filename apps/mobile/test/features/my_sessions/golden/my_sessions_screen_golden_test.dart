// Golden tests for MySessionsScreen.
// Two scales: 1.0 and 1.5. Fixed locale: th. Fixed theme.

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
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

const _fakeUser = UserEntity(
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

SessionEntity _session(String id) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: 'user-1',
    hostFaculty: 'Engineering',
    title: 'Upcoming Session $id',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['user-1'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Test User',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((_) => Stream.value(_fakeUser)),
      upcomingSessionsProvider(
        'user-1',
      ).overrideWith((_) => Stream.value([_session('s1'), _session('s2')])),
      completedSessionsProvider(
        'user-1',
      ).overrideWith((_) => Stream.value(const <SessionEntity>[])),
      hostedSessionsProvider(
        'user-1',
      ).overrideWith((_) => Stream.value(const <SessionEntity>[])),
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
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MySessionsScreen(),
      ),
    ),
  );
}

void main() {
  group('MySessionsScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MySessionsScreen),
          matchesGoldenFile('goldens/my_sessions_screen_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MySessionsScreen),
          matchesGoldenFile('goldens/my_sessions_screen_scale_1.5_th.png'),
        );
      });
    });
  });
}
