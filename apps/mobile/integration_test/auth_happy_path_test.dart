// Integration test: happy auth path — sign-up → verify → profile-setup → home.
//
// Requires Firebase emulators running before this test executes:
//   firebase emulators:start --only auth,firestore   (from repo root)
//
// Run on Android emulator (from apps/mobile/):
//   flutter test integration_test/auth_happy_path_test.dart -d emulator-5554
//
// Run on Chrome (from apps/mobile/ — requires chromedriver on port 4444):
//   flutter test integration_test/auth_happy_path_test.dart -d chrome
//
// Host selection:
//   Android emulator → 10.0.2.2 (loopback alias that reaches the host machine)
//   All other platforms → localhost
//
// Android auto-init note:
//   The debug AndroidManifest removes FirebaseInitProvider so that the
//   Firebase SDK does not auto-initialize before Dart code runs. This allows
//   setUpAll() to call Firebase.initializeApp() then useAuthEmulator() in the
//   correct order without hitting IllegalStateException. Release builds are
//   unaffected because they use the main AndroidManifest which retains the
//   provider.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Minimal test app wrapper ──────────────────────────────────────────────────
//
// Mirrors _StudyCollabApp in main.dart without Crashlytics wiring, which
// is not available in the test environment.

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Study Collab Integration Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Emulator host selection ────────────────────────────────────────────────
  //
  // Android emulator communicates with the host machine via 10.0.2.2.
  // Web/desktop/iOS simulator reaches the host as localhost.
  final String emulatorHost = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';

  setUpAll(() async {
    // Auto-init is disabled in debug Android builds via the debug
    // AndroidManifest (FirebaseInitProvider removed). On all platforms we
    // therefore always call initializeApp() here — no apps.isEmpty guard
    // needed or desired, because we need to be the first call to touch Auth.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Must be called immediately after initializeApp(), before any Firebase
    // Auth operation or internal state listener is attached by the plugin.
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  });

  // ── Helper: mark a Firebase Auth emulator account as email-verified ───────
  //
  // The Auth emulator exposes a REST endpoint to patch account state.
  // Uses package:http which works on all platforms (Android, iOS, Web).
  // dart:io HttpClient is not available on Web/JS and must not be used here.
  Future<void> markEmailVerified(String email) async {
    // Fetch the oobCode the emulator generated for this address.
    final oobUrl = Uri.http(
      '$emulatorHost:9099',
      '/emulator/v1/projects/study-collab-4d0a0/oobCodes',
    );
    final oobResponse = await http.get(oobUrl);
    final oobData = jsonDecode(oobResponse.body) as Map<String, dynamic>;
    final codes = oobData['oobCodes'] as List<dynamic>;
    final code = codes.lastWhere(
      (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL',
    );
    final oobCode = code['oobCode'] as String;

    // Follow the verify link so the emulator marks the account as verified.
    final verifyUrl = Uri.http('$emulatorHost:9099', '/emulator/action', {
      'mode': 'verifyEmail',
      'lang': 'en',
      'oobCode': oobCode,
      'apiKey': 'fake-api-key',
    });
    await http.get(verifyUrl);
  }

  testWidgets('happy path: sign-up → verify-email → profile-setup → home', (
    tester,
  ) async {
    // ── Unique email per run (cleanup strategy) ──────────────────────────
    //
    // Using a unique timestamp-based address on each run means:
    //   - No cleanup HTTP calls needed.
    //   - Re-runs never conflict with previous accounts.
    //   - The emulator is reset between CI jobs by design.
    final uniqueEmail =
        'test-${DateTime.now().millisecondsSinceEpoch}@mail.kmutt.ac.th';
    const password = 'Test1234!';

    // ── Step 1: launch the real app with real router ─────────────────────
    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── Step 2: navigate to sign-up ──────────────────────────────────────
    // Sign-in screen shows 'Welcome back!' and a link-style button to sign up.
    expect(find.text('Welcome back!'), findsOneWidget);

    // The sign-up navigation button says 'Create Account' on the sign-in screen.
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── Step 3: fill the sign-up form ────────────────────────────────────
    // Fields are found by index (no widget keys assigned — tracked as
    // flutter-engineer finding: sign_up_screen.dart fields missing Key()).
    //
    // TextFormField order on screen: Full name, Email, Password, Confirm Password.
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));

    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), uniqueEmail);
    await tester.enterText(fields.at(2), password);
    await tester.enterText(fields.at(3), password);

    // Tap the submit button identified by its label text.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ── Step 4: verify-email screen ──────────────────────────────────────
    expect(find.text('Verify your email'), findsOneWidget);

    // Mark the account as verified via the Auth emulator oobCode flow,
    // then reload so Firebase Auth picks up emailVerified = true.
    await markEmailVerified(uniqueEmail);
    await FirebaseAuth.instance.currentUser!.reload();

    // Tap the confirm button; the notifier calls reloadUser() which will
    // re-check auth state and transition to pendingProfileSetup.
    await tester.tap(
      find.widgetWithText(ElevatedButton, "I've verified my email"),
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // ── Step 5: profile-setup screen ─────────────────────────────────────
    expect(find.text('Set up your profile'), findsOneWidget);

    // Display name field is the first TextFormField on this screen.
    final profileFields = find.byType(TextFormField);
    await tester.enterText(profileFields.first, 'Test User');

    // Faculty dropdown — tap and choose first item.
    // byWidgetPredicate uses `is` (covariant) so it matches the concrete
    // DropdownButtonFormField<KmuttFaculty> type; byType<dynamic> would not.
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField).first,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap the first dropdown item in the overlay.
    final dropdownItems = find.byWidgetPredicate((w) => w is DropdownMenuItem);
    await tester.tap(dropdownItems.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save and continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ── Step 6: home screen ───────────────────────────────────────────────
    expect(find.text('Home'), findsWidgets);
  });
}
