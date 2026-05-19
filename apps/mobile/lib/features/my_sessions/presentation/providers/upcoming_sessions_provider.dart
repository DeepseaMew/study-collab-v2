import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/my_sessions/data/datasources/my_sessions_datasource.dart';
import 'package:mobile/features/my_sessions/data/repositories/my_sessions_repository_impl.dart';
import 'package:mobile/features/my_sessions/domain/repositories/my_sessions_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'upcoming_sessions_provider.g.dart';

/// Provides the [MySessionsRepository] implementation.
@riverpod
MySessionsRepository mySessionsRepository(MySessionsRepositoryRef ref) {
  return MySessionsRepositoryImpl(
    MySessionsDatasource(FirebaseFirestore.instance),
  );
}

/// Watches upcoming (non-ended) sessions for the current user.
@riverpod
Stream<List<SessionEntity>> upcomingSessions(
  UpcomingSessionsRef ref,
  String uid,
) {
  return ref.watch(mySessionsRepositoryProvider).watchUpcomingSessions(uid);
}
