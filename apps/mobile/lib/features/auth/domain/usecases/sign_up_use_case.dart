import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> execute({
    required String fullName,
    required String email,
    required String password,
  }) =>
      _repository.signUp(fullName: fullName, email: email, password: password);
}
