// Unit tests for RatingRepositoryImpl — methods that do not depend on
// FirebaseAuth.instance (ADR 0009).
//
// submitRatings() accesses FirebaseAuth.instance.currentUser which requires
// a live Firebase app; its error-mapping contract is covered by the
// integration tests in integration_test/rating_submit_test.dart.
//
// This file covers:
//   - watchSessionRatings: delegates to datasource and maps models → entities
//   - hasRatedInSession: delegates to datasource and returns its result
//   - RatingModel.toEntity: field mapping and Timestamp→DateTime conversion

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rating/data/datasources/rating_datasource.dart';
import 'package:mobile/features/rating/data/models/rating_model.dart';
import 'package:mobile/features/rating/data/repositories/rating_repository_impl.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockRatingDatasource extends Mock implements RatingDatasource {}

RatingModel _model({
  String ratingId = 'rater-1_ratee-2',
  String raterUid = 'rater-1',
  String rateeUid = 'ratee-2',
  bool liked = true,
  DateTime? ratedAt,
}) => RatingModel(
  ratingId: ratingId,
  raterUid: raterUid,
  rateeUid: rateeUid,
  liked: liked,
  ratedAt: ratedAt ?? DateTime(2026, 5, 25, 12),
);

void main() {
  late _MockRatingDatasource datasource;
  late RatingRepositoryImpl repo;

  setUp(() {
    datasource = _MockRatingDatasource();
    repo = RatingRepositoryImpl(datasource);
  });

  // ── RatingModel.toEntity ──────────────────────────────────────────────────

  group('RatingModel.toEntity — field mapping', () {
    test('maps all fields from model to entity', () {
      final ts = DateTime(2026, 5, 25, 12);
      final model = _model(
        ratingId: 'u1_u2',
        raterUid: 'u1',
        rateeUid: 'u2',
        ratedAt: ts,
      );

      final entity = model.toEntity();

      expect(entity.ratingId, 'u1_u2');
      expect(entity.raterUid, 'u1');
      expect(entity.rateeUid, 'u2');
      expect(entity.liked, isTrue);
      expect(entity.ratedAt, ts);
    });

    test('toEntity preserves liked = false (future-proofing)', () {
      final model = _model(liked: false);
      final entity = model.toEntity();
      expect(entity.liked, isFalse);
    });
  });

  // ── watchSessionRatings ───────────────────────────────────────────────────

  group('RatingRepositoryImpl.watchSessionRatings', () {
    test('emits empty list when datasource stream emits empty list', () async {
      when(
        () => datasource.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.value(const []));

      final result = await repo.watchSessionRatings('sess-1').first;

      expect(result, isEmpty);
    });

    test('maps RatingModel list to RatingEntity list', () async {
      final ts = DateTime(2026, 5, 25, 12);
      final models = [
        _model(ratingId: 'r1_r2', raterUid: 'r1', rateeUid: 'r2', ratedAt: ts),
        _model(ratingId: 'r3_r4', raterUid: 'r3', rateeUid: 'r4', ratedAt: ts),
      ];
      when(
        () => datasource.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.value(models));

      final entities = await repo.watchSessionRatings('sess-1').first;

      expect(entities, hasLength(2));
      expect(entities[0], isA<RatingEntity>());
      expect(entities[0].ratingId, 'r1_r2');
      expect(entities[1].rateeUid, 'r4');
    });

    test('passes sessionId to datasource unchanged', () async {
      when(
        () => datasource.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.value(const []));

      await repo.watchSessionRatings('sess-specific').first;

      verify(() => datasource.watchSessionRatings('sess-specific')).called(1);
    });

    test('propagates stream errors from datasource', () async {
      when(
        () => datasource.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.error(Exception('Firestore error')));

      await expectLater(
        repo.watchSessionRatings('sess-1'),
        emitsError(isA<Exception>()),
      );
    });

    test('stream with multiple events maps each correctly', () async {
      final first = [_model(ratingId: 'a_b', raterUid: 'a', rateeUid: 'b')];
      final second = [
        _model(ratingId: 'a_b', raterUid: 'a', rateeUid: 'b'),
        _model(ratingId: 'c_d', raterUid: 'c', rateeUid: 'd'),
      ];
      when(
        () => datasource.watchSessionRatings(any()),
      ).thenAnswer((_) => Stream.fromIterable([first, second]));

      final emissions = await repo.watchSessionRatings('sess-1').toList();

      expect(emissions[0], hasLength(1));
      expect(emissions[1], hasLength(2));
    });
  });

  // ── hasRatedInSession ─────────────────────────────────────────────────────

  group('RatingRepositoryImpl.hasRatedInSession', () {
    test('returns true when datasource returns true', () async {
      when(
        () => datasource.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => true);

      final result = await repo.hasRatedInSession('sess-1', 'user-1');

      expect(result, isTrue);
    });

    test('returns false when datasource returns false', () async {
      when(
        () => datasource.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => false);

      final result = await repo.hasRatedInSession('sess-1', 'user-1');

      expect(result, isFalse);
    });

    test('passes sessionId and raterUid to datasource unchanged', () async {
      when(
        () => datasource.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => false);

      await repo.hasRatedInSession('sess-specific', 'rater-specific');

      verify(
        () => datasource.hasRatedInSession('sess-specific', 'rater-specific'),
      ).called(1);
    });

    test('propagates exception from datasource', () async {
      when(() => datasource.hasRatedInSession(any(), any())).thenAnswer(
        (_) => Future.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      await expectLater(
        repo.hasRatedInSession('sess-1', 'user-1'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
