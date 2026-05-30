import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class ReloadUserUseCase {
  const ReloadUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> execute() => _repository.reloadUser();
}
