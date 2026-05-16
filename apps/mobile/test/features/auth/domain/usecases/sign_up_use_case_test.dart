import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockRepo;
  late SignUpUseCase useCase;

  setUp(() {
    mockRepo = _MockAuthRepository();
    useCase = SignUpUseCase(mockRepo);
  });

  test('happy path — delegates to repository', () async {
    when(
      () => mockRepo.signUp(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    await useCase.execute(
      fullName: 'Test User',
      email: 'test@mail.kmutt.ac.th',
      password: 'password123',
    );

    verify(
      () => mockRepo.signUp(
        fullName: 'Test User',
        email: 'test@mail.kmutt.ac.th',
        password: 'password123',
      ),
    ).called(1);
  });

  test('failure path — propagates KmuttDomainRejected', () async {
    when(
      () => mockRepo.signUp(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthFailure.kmuttDomainRejected());

    expect(
      () => useCase.execute(
        fullName: 'Test User',
        email: 'test@gmail.com',
        password: 'password123',
      ),
      throwsA(isA<AuthFailure>()),
    );
  });
}
