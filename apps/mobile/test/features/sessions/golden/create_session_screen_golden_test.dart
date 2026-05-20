// Golden tests for CreateSessionScreen.
// Two scales: 1.0 and 1.5. Fixed locale: th. Fixed theme.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/create_session_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _MockSessionRepository extends Mock implements SessionRepository {}

Widget _buildScreen(double textScale) {
  final repo = _MockSessionRepository();

  registerFallbackValue(
    SessionEntity(
      sessionId: '',
      hostUid: 'u1',
      hostFaculty: 'Engineering',
      title: 'T',
      hashtags: const [],
      academicLevel: 'undergraduate',
      studentYear: 1,
      visibility: 'public',
      memberUids: const [],
      noteCount: 0,
      status: 'scheduled',
      scheduledAt: DateTime(2026, 5, 19, 10),
      scheduledEndAt: DateTime(2026, 5, 19, 12),
      location: 'CB2308',
      capacity: 5,
      hostDisplayName: 'Test User',
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
    ),
  );

  when(
    () => repo.createSession(any(), plainTextPin: any(named: 'plainTextPin')),
  ).thenAnswer((_) async {});

  const fakeUser = UserEntity(
    uid: 'u1',
    displayName: 'Test User',
    fullName: 'Test Full User',
    email: 'user1@mail.kmutt.ac.th',
    hasHostedBefore: false,
    studentYear: 2,
    academicLevel: 'undergraduate',
    faculty: 'Engineering',
    profileScore: 0.0,
  );

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser('u1')),
      ),
      userProvider('u1').overrideWith((_) => Stream.value(fakeUser)),
      sessionRepositoryProvider.overrideWithValue(repo),
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
        child: const CreateSessionScreen(),
      ),
    ),
  );
}

void main() {
  group('CreateSessionScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(CreateSessionScreen),
          matchesGoldenFile('goldens/create_session_screen_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(CreateSessionScreen),
          matchesGoldenFile('goldens/create_session_screen_scale_1.5_th.png'),
        );
      });
    });
  });
}
