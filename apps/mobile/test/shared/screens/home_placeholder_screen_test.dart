import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _stubUser = UserEntity(
  uid: 'test-uid',
  displayName: 'Test Student',
  fullName: 'Test Student',
  email: 'test@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 1,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser('test-uid')),
      ),
      userProvider('test-uid').overrideWith((_) => Stream.value(_stubUser)),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('HomeScreen renders Scaffold', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Scaffold must be present.
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('HomeScreen shows greeting with user first name', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Greeting text contains first name from displayName.
    // Match the appBar title text which is a greeting containing the name.
    expect(find.textContaining('Test Student'.split(' ').first), findsWidgets);
  });
}
