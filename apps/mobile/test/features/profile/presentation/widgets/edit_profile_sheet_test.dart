// Widget tests for EditProfileSheet.
//
// Tests:
//   - Renders with pre-filled displayName field
//   - Save button disabled (or calls nothing) when displayName field is cleared

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/domain/repositories/user_repository.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _MockUserRepository extends Mock implements UserRepository {}

const _uid = 'test-uid';

const _stubUser = UserEntity(
  uid: _uid,
  displayName: 'Alice Smith',
  fullName: 'Alice Smith',
  email: 'alice@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  bio: 'A short bio',
  profileScore: 0.0,
);

Widget _buildSheet({UserRepository? mockRepo}) {
  final repo = mockRepo ?? _MockUserRepository();
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      userRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: ctx,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditProfileSheet(user: _stubUser),
            ),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders with pre-filled displayName field',
    (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The displayName text field must be pre-filled with the user's name.
      expect(find.widgetWithText(TextField, 'Alice Smith'), findsOneWidget);
    },
  );

  testWidgets(
    'Save button does not call repository when displayName field is cleared',
    (tester) async {
      final mockRepo = _MockUserRepository();

      await tester.pumpWidget(_buildSheet(mockRepo: mockRepo));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Clear the name field.
      await tester.enterText(
        find.widgetWithText(TextField, 'Alice Smith'),
        '',
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Save Changes.
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // updateProfile must never be called when the name is empty
      // (EditProfileSheet._save returns early if _nameCtrl.text.trim().isEmpty).
      verifyNever(() => mockRepo.updateProfile(any(), any()));
    },
  );
}
