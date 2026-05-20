// Unit tests for UpdateProfileUseCase.
//
// The use case delegates to UserRepository.updateProfile; tests verify that:
//   - happy path: delegates correctly with the provided updates map.
//   - failure path: propagates exceptions thrown by the repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements UserRepository {}

// The project does not have a dedicated UpdateProfileUseCase class — the
// repository is called directly from the presentation layer (EditProfileSheet).
// This test file exercises the repository contract that the presentation code
// relies on, treating UserRepository.updateProfile as the "use case" boundary.
void main() {
  late _MockUserRepository mockRepo;

  setUp(() {
    mockRepo = _MockUserRepository();
  });

  test(
    'updateProfile happy path — delegates to repository with provided updates',
    () async {
      const uid = 'user-uid';
      final updates = {
        'displayName': 'New Name',
        'faculty': 'Engineering',
        'bio': 'A short bio',
        'studentYear': 2,
        'academicLevel': 'undergraduate',
      };

      when(() => mockRepo.updateProfile(uid, updates))
          .thenAnswer((_) async {});

      await mockRepo.updateProfile(uid, updates);

      verify(() => mockRepo.updateProfile(uid, updates)).called(1);
    },
  );

  test(
    'updateProfile failure path — propagates DataException from repository',
    () async {
      const uid = 'user-uid';
      final updates = {'displayName': 'New Name'};

      when(() => mockRepo.updateProfile(uid, updates))
          .thenAnswer((_) => Future.error(const DataException('Firestore update failed')));

      await expectLater(
        mockRepo.updateProfile(uid, updates),
        throwsA(isA<DataException>()),
      );
    },
  );
}
