import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/reload_user_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockRepo;
  late ReloadUserUseCase useCase;

  setUp(() {
    mockRepo = _MockAuthRepository();
    useCase = ReloadUserUseCase(mockRepo);
  });

  test('happy path — delegates to repository', () async {
    when(() => mockRepo.reloadUser()).thenAnswer((_) async {});

    await useCase.execute();

    verify(() => mockRepo.reloadUser()).called(1);
  });

  test('failure path — propagates NetworkFailure', () async {
    when(
      () => mockRepo.reloadUser(),
    ).thenThrow(const AuthFailure.networkFailure());

    expect(() => useCase.execute(), throwsA(isA<AuthFailure>()));
  });
}
