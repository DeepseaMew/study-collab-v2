import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _stubUser = UserEntity(
  uid: 'test-uid',
  displayName: 'Test Student',
  fullName: 'Test Student',
  email: 'test@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 1,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser('test-uid')),
      ),
      userProvider('test-uid').overrideWith(
        (_) => Stream.value(_stubUser),
      ),
      publicSessionsStreamProvider.overrideWith(
        (_) => Stream<List<SessionEntity>>.value(const []),
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
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  group('HomeScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_placeholder_screen_scale_1.0_th.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_placeholder_screen_scale_1.5_th.png'),
      );
    });
  });
}
