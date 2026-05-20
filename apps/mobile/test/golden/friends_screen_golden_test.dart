// Golden tests for FriendsScreen.
//
// Covers scale 1.0 and 1.5 at locale 'th' with a fixed ThemeData and empty
// friends + requests (stable state — no network images).
//
// DO NOT run flutter test --update-goldens without human approval.
// Write the test code only; a human must run --update-goldens to generate PNGs.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friends_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _uid = 'golden-uid';

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      friendsProvider(_uid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      incomingRequestsProvider(_uid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
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
        child: const FriendsScreen(),
      ),
    ),
  );
}

void main() {
  group('FriendsScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(FriendsScreen),
        matchesGoldenFile('goldens/friends_screen_scale_1.0_th.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(FriendsScreen),
        matchesGoldenFile('goldens/friends_screen_scale_1.5_th.png'),
      );
    });
  });
}
