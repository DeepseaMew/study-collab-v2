import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/user_repository_impl.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_provider.g.dart';

/// Provides the [UserRepository] implementation wired to Firestore.
///
/// [ProfileDatasource.withDefaultFirestore] is called here — inside the
/// `@riverpod` body — so no `cloud_firestore` import is needed in this file.
@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  return UserRepositoryImpl(ProfileDatasource.withDefaultFirestore());
}

/// Streams a [UserEntity] by [uid].
/// Emits `null` when the document does not exist or the user is not found.
@riverpod
Stream<UserEntity?> user(UserRef ref, String uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
}
