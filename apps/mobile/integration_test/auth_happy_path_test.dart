// Integration test: happy auth path — sign-up → verify → profile-setup → home.
//
// This test is scaffolded to compile and be tracked in CI without blocking it.
// Emulator wiring is deferred: see follow-up note at the bottom of this file.
//
// To run against a live emulator:
//   1. Start Firebase emulators: `firebase emulators:start --only auth,firestore`
//   2. Remove the `skip:` argument from the testWidgets call below.
//   3. Run: `flutter test integration_test/auth_happy_path_test.dart`

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'happy path: sign-up → verify-email → profile-setup → home',
    (tester) async {
      // TODO: wire emulator
      // Step 0 — initialise Firebase and point SDKs at local emulators.
      //
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
      // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      // FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

      // Step 1 — launch the app with real router (no provider overrides).
      //
      // final uniqueEmail =
      //   'test+${DateTime.now().millisecondsSinceEpoch}@mail.kmutt.ac.th';
      // const password = 'Test1234!';
      //
      // await tester.pumpWidget(const ProviderScope(child: MyApp()));
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // Step 2 — navigate to sign-up and submit valid KMUTT credentials.
      //
      // expect(find.text('Welcome back!'), findsOneWidget);
      // await tester.tap(find.text('Create Account'));
      // await tester.pumpAndSettle(const Duration(seconds: 3));
      // await tester.enterText(find.byKey(const Key('fullNameField')), 'Test User');
      // await tester.enterText(find.byKey(const Key('emailField')), uniqueEmail);
      // await tester.enterText(find.byKey(const Key('passwordField')), password);
      // await tester.enterText(find.byKey(const Key('confirmPasswordField')), password);
      // await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      // await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 3 — verify email (emulator auto-confirms via applyActionCode or
      //   by calling the emulator REST API to set emailVerified = true).
      //
      // expect(find.text('Verify your email'), findsOneWidget);
      // Firebase Auth emulator: mark email as verified via REST.
      // final uid = FirebaseAuth.instance.currentUser!.uid;
      // // PUT http://localhost:9099/emulator/v1/projects/<project>/accounts
      // // is the canonical emulator override endpoint.
      // // After marking verified, tap the confirm button.
      // await tester.tap(find.widgetWithText(ElevatedButton, "I've verified my email"));
      // await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 4 — complete profile-setup.
      //
      // expect(find.text('Set up your profile'), findsOneWidget);
      // await tester.enterText(
      //   find.byKey(const Key('displayNameField')), 'Test User');
      // // Select first faculty from dropdown.
      // await tester.tap(find.byType(DropdownButtonFormField<dynamic>).first);
      // await tester.pumpAndSettle(const Duration(seconds: 2));
      // await tester.tap(find.text('Engineering').last);
      // await tester.pumpAndSettle(const Duration(seconds: 2));
      // await tester.tap(find.widgetWithText(ElevatedButton, 'Save and continue'));
      // await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 5 — assert router has navigated to /home.
      //
      // expect(find.text('Home'), findsWidgets);

      // Placeholder assertion so the test body is non-empty and compiles.
      expect(true, isTrue);
    },
    // skip: true — remove this line to run against a live emulator.
    skip: true,
  );
}

// Follow-up: wire emulator in a dedicated CI job.
// Tracked as integration test scaffolded (emulator wiring deferred) in
// docs/audit/qa-feat-auth.md Coverage Expansion section.
