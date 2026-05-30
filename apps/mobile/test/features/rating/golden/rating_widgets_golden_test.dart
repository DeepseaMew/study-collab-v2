// Golden tests for Rating widgets (ADR 0009).
//
// Captures baseline screenshots for:
//   - RatingBottomSheet — all members unselected (Submit disabled)
//   - RatingBottomSheet — one member selected (Submit enabled)
//   - RatingBannerWidget — banner card visible
//   - ProfileScoreWidget — zero score ("No ratings yet")
//   - ProfileScoreWidget — positive score ("85% positive")
//
// To regenerate: flutter test --update-goldens
//   test/features/rating/golden/rating_widgets_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:mobile/features/rating/presentation/providers/session_ratings_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/profile_score_widget.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_banner_widget.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_bottom_sheet.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _sessionId = 'sess-golden';
const _currentUid = 'user-current';
const _hostUid = 'user-host';

UserEntity _user(String uid, {String? name}) => UserEntity(
  uid: uid,
  displayName: name ?? 'User $uid',
  fullName: 'Full $uid',
  email: '$uid@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

final _members = [
  _user(_currentUid, name: 'Nichapa J'),
  _user(_hostUid, name: 'Host Member'),
  _user('member-a', name: 'Aran K'),
  _user('member-b', name: 'Pim S'),
];

ThemeData _theme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    error: AppColors.error,
    surface: AppColors.background,
  ),
  textTheme: AppTypography.textTheme,
  useMaterial3: true,
);

_MockRatingRepository _mockRepo() {
  final repo = _MockRatingRepository();
  when(() => repo.submitRatings(any(), any())).thenAnswer((_) async {});
  when(
    () => repo.watchSessionRatings(any()),
  ).thenAnswer((_) => Stream.value(const []));
  when(
    () => repo.hasRatedInSession(any(), any()),
  ).thenAnswer((_) async => false);
  return repo;
}

// ── Bottom Sheet golden wrappers ──────────────────────────────────────────────

class _FakeIdleNotifier extends RatingNotifier {
  @override
  AsyncValue<void> build(String sessionId) => const AsyncValue.data(null);
}

Widget _bottomSheetHost() {
  return ProviderScope(
    overrides: [
      ratingEnabledProvider.overrideWithValue(true),
      hasRatedProvider(
        _sessionId,
        _currentUid,
      ).overrideWith((_) async => false),
      ratingRepositoryProvider.overrideWithValue(_mockRepo()),
      sessionRatingsProvider(
        _sessionId,
      ).overrideWith((_) => Stream.value(const <RatingEntity>[])),
      ratingNotifierProvider(
        _sessionId,
      ).overrideWith(() => _FakeIdleNotifier()),
    ],
    child: MaterialApp(
      theme: _theme(),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RatingBottomSheet(
                  sessionId: _sessionId,
                  members: _members,
                  currentUserId: _currentUid,
                  hostUid: _hostUid,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Rating goldens', () {
    testWidgets('RatingBottomSheet — all unselected (Submit disabled)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_bottomSheetHost());
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(RatingBottomSheet),
          matchesGoldenFile('goldens/rating_bottom_sheet_unselected.png'),
        );
      });
    });

    testWidgets('RatingBottomSheet — one member selected (Submit enabled)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_bottomSheetHost());
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Toggle the first rateable member (Host Member)
        await tester.tap(find.byIcon(Icons.thumb_up_outlined).first);
        await tester.pump();

        await expectLater(
          find.byType(RatingBottomSheet),
          matchesGoldenFile('goldens/rating_bottom_sheet_selected.png'),
        );
      });
    });

    testWidgets('RatingBannerWidget — banner card visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ratingEnabledProvider.overrideWithValue(true),
            hasRatedProvider(
              _sessionId,
              _currentUid,
            ).overrideWith((_) async => false),
            ratingRepositoryProvider.overrideWithValue(_mockRepo()),
            sessionRatingsProvider(
              _sessionId,
            ).overrideWith((_) => Stream.value(const [])),
          ],
          child: MaterialApp(
            theme: _theme(),
            home: Scaffold(
              backgroundColor: AppColors.background,
              body: Column(
                children: [
                  RatingBannerWidget(
                    sessionId: _sessionId,
                    currentUserId: _currentUid,
                    members: _members,
                    hostUid: _hostUid,
                    sessionStatus: 'ended',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(RatingBannerWidget),
        matchesGoldenFile('goldens/rating_banner.png'),
      );
    });

    testWidgets('ProfileScoreWidget — zero score ("No ratings yet")', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: const Scaffold(
            body: Center(
              child: ProfileScoreWidget(
                profileScore: 0.0,
                completedSessionCount: 0,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ProfileScoreWidget),
        matchesGoldenFile('goldens/profile_score_zero.png'),
      );
    });

    testWidgets('ProfileScoreWidget — 85% positive rating', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: const Scaffold(
            body: Center(
              child: ProfileScoreWidget(
                profileScore: 0.85,
                completedSessionCount: 7,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ProfileScoreWidget),
        matchesGoldenFile('goldens/profile_score_positive.png'),
      );
    });
  });
}
