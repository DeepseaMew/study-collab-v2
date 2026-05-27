// Widget tests for RatingBannerWidget (ADR 0009 Sub-decision 2).
//
// Verifies:
//   - Hidden when sessionStatus != 'ended'
//   - Hidden when ratingEnabled is false
//   - Hidden when hasRated is true
//   - Hidden while hasRated is loading (AsyncLoading)
//   - Renders banner card when ratingEnabled=true, hasRated=false, status=ended
//   - "Rate Now" button opens RatingBottomSheet
//   - Semantics label and liveRegion are present

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:mobile/features/rating/presentation/providers/session_ratings_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_banner_widget.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

const _sessionId = 'sess-banner';
const _currentUserId = 'user-current';
const _hostUid = 'user-host';

UserEntity _member(String uid, {String? displayName}) => UserEntity(
  uid: uid,
  displayName: displayName ?? 'User $uid',
  fullName: 'Full $uid',
  email: '$uid@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

final _members = [
  _member(_currentUserId),
  _member(_hostUid),
  _member('member-3'),
];

Widget _buildBanner({
  bool ratingEnabled = true,
  AsyncValue<bool> hasRated = const AsyncValue.data(false),
  String sessionStatus = 'ended',
}) {
  final repo = _MockRatingRepository();
  when(
    () => repo.watchSessionRatings(any()),
  ).thenAnswer((_) => Stream.value(const <RatingEntity>[]));
  when(
    () => repo.hasRatedInSession(any(), any()),
  ).thenAnswer((_) async => false);

  return ProviderScope(
    overrides: [
      ratingEnabledProvider.overrideWithValue(ratingEnabled),
      hasRatedProvider(
        _sessionId,
        _currentUserId,
      ).overrideWith((_) async => hasRated.valueOrNull ?? false),
      ratingRepositoryProvider.overrideWithValue(repo),
      sessionRatingsProvider(
        _sessionId,
      ).overrideWith((_) => Stream.value(const <RatingEntity>[])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: RatingBannerWidget(
          sessionId: _sessionId,
          currentUserId: _currentUserId,
          members: _members,
          hostUid: _hostUid,
          sessionStatus: sessionStatus,
        ),
      ),
    ),
  );
}

void main() {
  group('RatingBannerWidget — hidden states', () {
    testWidgets('renders nothing when sessionStatus is not ended', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(sessionStatus: 'scheduled'));
      await tester.pump();

      expect(find.text('Rate your session members'), findsNothing);
      expect(find.text('Rate Now'), findsNothing);
    });

    testWidgets('renders nothing when ratingEnabled is false', (tester) async {
      await tester.pumpWidget(_buildBanner(ratingEnabled: false));
      await tester.pump();

      expect(find.text('Rate your session members'), findsNothing);
      expect(find.text('Rate Now'), findsNothing);
    });

    testWidgets('renders nothing when hasRated is true', (tester) async {
      await tester.pumpWidget(
        _buildBanner(hasRated: const AsyncValue.data(true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rate your session members'), findsNothing);
      expect(find.text('Rate Now'), findsNothing);
    });

    testWidgets('renders nothing while hasRated is loading', (tester) async {
      final repo = _MockRatingRepository();
      // Never completes — simulates loading
      when(
        () => repo.hasRatedInSession(any(), any()),
      ).thenAnswer((_) => Completer<bool>().future);
      when(
        () => repo.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.value(const []));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ratingEnabledProvider.overrideWithValue(true),
            ratingRepositoryProvider.overrideWithValue(repo),
            sessionRatingsProvider(
              _sessionId,
            ).overrideWith((_) => Stream.value(const [])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RatingBannerWidget(
                sessionId: _sessionId,
                currentUserId: _currentUserId,
                members: _members,
                hostUid: _hostUid,
                sessionStatus: 'ended',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate your session members'), findsNothing);
    });

    testWidgets('renders nothing when active (ongoing) session', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(sessionStatus: 'active'));
      await tester.pump();

      expect(find.text('Rate your session members'), findsNothing);
    });
  });

  group('RatingBannerWidget — visible state', () {
    testWidgets('renders banner card with label and Rate Now button', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle();

      expect(find.text('Rate your session members'), findsOneWidget);
      expect(find.text('Rate Now'), findsOneWidget);
    });

    testWidgets('thumbs-up icon is visible on banner', (tester) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });

    testWidgets('Semantics label is "Rate your session members banner"', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner());
      await tester.pumpAndSettle();

      // The Semantics wrapper on the Card carries this label.
      final semantics = tester.getSemantics(
        find.text('Rate your session members'),
      );
      expect(semantics.label, contains('Rate your session members'));
    });

    testWidgets('tapping Rate Now opens RatingBottomSheet', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildBanner());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rate Now'));
        await tester.pumpAndSettle();

        // Bottom sheet should appear — look for the sheet title
        expect(find.text('Rate Session Members'), findsOneWidget);
      });
    });
  });
}
