import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class CompleteProfileSetupUseCase {
  const CompleteProfileSetupUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> execute({
    required String displayName,
    required String faculty,
    required String bio,
  }) =>
      _repository.completeProfileSetup(
        displayName: displayName,
        faculty: faculty,
        bio: bio,
      );
}
