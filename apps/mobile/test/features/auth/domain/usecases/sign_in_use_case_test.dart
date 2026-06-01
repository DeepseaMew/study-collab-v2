import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockRepo;
  late SignInUseCase useCase;

  setUp(() {
    mockRepo = _MockAuthRepository();
    useCase = SignInUseCase(mockRepo);
  });

  test('happy path — delegates to repository', () async {
    when(
      () => mockRepo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    await useCase.execute(
      email: 'test@mail.kmutt.ac.th',
      password: 'password123',
    );

    verify(
      () => mockRepo.signIn(
        email: 'test@mail.kmutt.ac.th',
        password: 'password123',
      ),
    ).called(1);
  });

  test('failure path — propagates AuthFailure', () async {
    when(
      () => mockRepo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthFailure.invalidCredentials());

    expect(
      () => useCase.execute(email: 'test@mail.kmutt.ac.th', password: 'wrong'),
      throwsA(isA<AuthFailure>()),
    );
  });
}
