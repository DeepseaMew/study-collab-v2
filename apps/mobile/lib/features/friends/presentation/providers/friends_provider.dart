import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mobile/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'friends_provider.g.dart';

/// Provides the [FriendsRepository] implementation.
///
/// [FriendsDatasource.withDefaultFirestore] is called here — inside the
/// `@riverpod` body — so no `cloud_firestore` import is needed in this file.
@riverpod
FriendsRepository friendsRepository(FriendsRepositoryRef ref) {
  return FriendsRepositoryImpl(FriendsDatasource.withDefaultFirestore());
}

/// Watches accepted friends for [uid].
@riverpod
Stream<List<FriendEntity>> friends(FriendsRef ref, String uid) {
  return ref.watch(friendsRepositoryProvider).watchFriends(uid);
}
