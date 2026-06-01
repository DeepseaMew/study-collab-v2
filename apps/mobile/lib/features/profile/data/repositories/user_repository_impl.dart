import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';

/// Firestore-backed implementation of [UserRepository].
class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl(this._datasource);

  final ProfileDatasource _datasource;

  @override
  Stream<UserEntity?> watchUser(String uid) {
    return _datasource.watchUser(uid).map((model) => model?.toEntity());
  }

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> updates) {
    return _datasource.updateProfile(uid, updates);
  }
}
