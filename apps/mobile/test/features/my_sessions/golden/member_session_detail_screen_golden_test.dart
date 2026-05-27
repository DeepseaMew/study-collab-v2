// Golden tests for MemberSessionDetailScreen.
// Two scales: 1.0 and 1.5. Fixed locale: th. Fixed theme.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/my_sessions/presentation/screens/member_session_detail_screen.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
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

SessionEntity _session() {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: 'sess-golden-member',
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Data Structures Study Group',
    description: 'A session about algorithms.',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-1', 'member-1'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      sessionStreamProvider(
        'sess-golden-member',
      ).overrideWith((_) => Stream.value(_session())),
      sessionMembersProvider(
        'sess-golden-member',
      ).overrideWith((_) => Stream.value(const <UserEntity>[])),
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser('member-1')),
      ),
      ratingEnabledProvider.overrideWithValue(false),
      hasRatedProvider('sess-golden-member', 'member-1').overrideWith(
        (_) async => false,
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
        child: const MemberSessionDetailScreen(sessionId: 'sess-golden-member'),
      ),
    ),
  );
}

void main() {
  group('MemberSessionDetailScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MemberSessionDetailScreen),
          matchesGoldenFile(
            'goldens/member_session_detail_screen_scale_1.0_th.png',
          ),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(MemberSessionDetailScreen),
          matchesGoldenFile(
            'goldens/member_session_detail_screen_scale_1.5_th.png',
          ),
        );
      });
    });
  });
}
