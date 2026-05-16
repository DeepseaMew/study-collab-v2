import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockRepo;
  late SignOutUseCase useCase;

  setUp(() {
    mockRepo = _MockAuthRepository();
    useCase = SignOutUseCase(mockRepo);
  });

  test('happy path — delegates to repository', () async {
    when(() => mockRepo.signOut()).thenAnswer((_) async {});

    await useCase.execute();

    verify(() => mockRepo.signOut()).called(1);
  });

  test('failure path — propagates AuthFailure', () async {
    when(
      () => mockRepo.signOut(),
    ).thenThrow(const AuthFailure.unknownFailure());

    expect(() => useCase.execute(), throwsA(isA<AuthFailure>()));
  });
}
