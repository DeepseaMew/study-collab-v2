// Golden tests for OtherUserProfileScreen (data state — other user loaded).
//
// Covers scale 1.0 and 1.5 at locale 'th' with a fixed ThemeData.
//
// DO NOT run flutter test --update-goldens without human approval.
// Write the test code only; a human must run --update-goldens to generate PNGs.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/providers/outgoing_requests_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/screens/other_user_profile_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _viewerUid = 'viewer-golden-uid';
const _targetUid = 'target-golden-uid';

const _viewerUser = UserEntity(
  uid: _viewerUid,
  displayName: 'Viewer User',
  fullName: 'Viewer User',
  email: 'viewer@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

const _targetUser = UserEntity(
  uid: _targetUid,
  displayName: 'Alice Wonderland',
  fullName: 'Alice Wonderland',
  email: 'alice@mail.kmutt.ac.th',
  hasHostedBefore: true,
  studentYear: 3,
  academicLevel: 'undergraduate',
  faculty: 'Science',
  bio: 'Loves mathematics and group study.',
  profileScore: 0.85,
);

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_viewerUid)),
      ),
      userProvider(_targetUid).overrideWith(
        (_) => Stream.value(_targetUser),
      ),
      userProvider(_viewerUid).overrideWith(
        (_) => Stream.value(_viewerUser),
      ),
      friendsProvider(_viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      incomingRequestsProvider(_viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      outgoingRequestsProvider(_viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      sessionsByUserProvider(_targetUid).overrideWith(
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
        child: const OtherUserProfileScreen(userId: _targetUid),
      ),
    ),
  );
}

void main() {
  group('OtherUserProfileScreen golden', () {
    testWidgets('scale 1.0 — th locale — data state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(OtherUserProfileScreen),
          matchesGoldenFile(
            'goldens/other_user_profile_screen_scale_1.0_th.png',
          ),
        );
      });
    });

    testWidgets('scale 1.5 — th locale — data state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(OtherUserProfileScreen),
          matchesGoldenFile(
            'goldens/other_user_profile_screen_scale_1.5_th.png',
          ),
        );
      });
    });
  });
}
