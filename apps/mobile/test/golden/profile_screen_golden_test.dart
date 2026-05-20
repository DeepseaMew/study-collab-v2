// Golden tests for ProfileScreen (own profile, no sessions).
//
// Covers scale 1.0 and 1.5 at locale 'th' with a fixed ThemeData.
//
// DO NOT run flutter test --update-goldens without human approval.
// Write the test code only; a human must run --update-goldens to generate PNGs.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _FakeAvatarUpload extends AvatarUpload {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

const _uid = 'golden-uid';

const _stubUser = UserEntity(
  uid: _uid,
  displayName: 'Golden User',
  fullName: 'Golden User',
  email: 'golden@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 3,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

GoRouter _stubRouter() => GoRouter(
  initialLocation: '/profile',
  redirect: (_, state) {
    if (state.uri.path == '/sign-in') return '/profile';
    return null;
  },
  routes: [
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/sign-in', builder: (_, __) => const Scaffold()),
  ],
);

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      userProvider(_uid).overrideWith((_) => Stream.value(_stubUser)),
      friendsProvider(
        _uid,
      ).overrideWith((_) => Stream<List<FriendEntity>>.value(const [])),
      upcomingSessionsProvider(
        _uid,
      ).overrideWith((_) => Stream<List<SessionEntity>>.value(const [])),
      completedSessionsProvider(
        _uid,
      ).overrideWith((_) => Stream<List<SessionEntity>>.value(const [])),
      avatarUploadProvider.overrideWith(() => _FakeAvatarUpload()),
      localBytesStreamProvider(
        _uid,
      ).overrideWith((_) => Stream<List<int>?>.value(null)),
    ],
    child: MaterialApp.router(
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
      routerConfig: _stubRouter(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

void main() {
  group('ProfileScreen golden', () {
    testWidgets('scale 1.0 — th locale — own profile, no sessions', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/profile_screen_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale — own profile, no sessions', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/profile_screen_scale_1.5_th.png'),
        );
      });
    });
  });
}
