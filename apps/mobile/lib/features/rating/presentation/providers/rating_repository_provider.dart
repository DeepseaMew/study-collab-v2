import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/features/rating/data/datasources/rating_datasource.dart';
import 'package:mobile/features/rating/data/repositories/rating_repository_impl.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_repository_provider.g.dart';

@Riverpod(keepAlive: true)
RatingDatasource ratingDatasource(RatingDatasourceRef ref) => RatingDatasource(
      FirebaseFirestore.instance,
      // Crashlytics is not supported on Web.
      kIsWeb ? null : FirebaseCrashlytics.instance,
    );

@Riverpod(keepAlive: true)
RatingRepository ratingRepository(RatingRepositoryRef ref) {
  final datasource = ref.watch(ratingDatasourceProvider);
  // _currentUserId is intentionally NOT passed from this provider.
  // RatingRepositoryImpl fetches FirebaseAuth.instance.currentUser?.uid fresh
  // on every write call so that a keepAlive provider constructed before auth
  // completes cannot produce a stale (empty) raterUid in the batch payload.
  return RatingRepositoryImpl(datasource);
}
