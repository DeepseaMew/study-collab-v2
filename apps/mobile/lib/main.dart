import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/firebase_options.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Router ─────────────────────────────────────────────────────────────────────
//
// TODO(auth-guard): Add a redirect callback here once the Auth feature is
// implemented. The guard should check FirebaseAuth.instance.currentUser and
// redirect unauthenticated users to the sign-in route. See ADR 0001.
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _HomeScreen()),
  ],
);

// ── Bootstrap ─────────────────────────────────────────────────────────────────

Future<void> main() async {
  // runZonedGuarded is the outermost error boundary. All unhandled async errors
  // that escape the Flutter framework are caught here and sent to Crashlytics.
  await runZonedGuarded<Future<void>>(_bootstrap, (
    Object error,
    StackTrace stack,
  ) {
    appLogger.error(
      'Unhandled error in root zone',
      exception: error,
      stackTrace: stack,
    );
    // Non-fatal: allow the app to continue if possible.
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase initialization.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Firestore offline persistence (ADR 0002 — Option C).
  //    Android/iOS: enabled by default. Web: requires explicit opt-in.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    // Unbounded cache keeps study session history available offline.
    // A future ADR may set a bounded value if storage pressure is reported.
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 3a. Crashlytics — Flutter framework errors (fatal).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // 3b. Crashlytics — Platform dispatcher errors that escape the framework.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // Error has been handled; do not propagate further.
  };

  appLogger.info('App bootstrap complete — launching Study Collab');

  runApp(
    // 4. Riverpod — wrap the entire widget tree in ProviderScope.
    const ProviderScope(child: _StudyCollabApp()),
  );
}

// ── App widget ─────────────────────────────────────────────────────────────────

class _StudyCollabApp extends StatelessWidget {
  const _StudyCollabApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Study Collab',
      debugShowCheckedModeBanner: false,
      // 5. Theme — use design-system tokens from app_colors.dart and
      //    app_typography.dart. Both files exist in this project.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      // 6. GoRouter.
      routerConfig: _router,
    );
  }
}

// ── Placeholder home screen ────────────────────────────────────────────────────

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Study Collab')),
      // 7. Debug-only test crash button.
      //    This FloatingActionButton is ONLY compiled into debug builds.
      //    It will not appear in profile or release builds.
      //    Purpose: verify that Crashlytics is receiving data before release.
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: () {
                appLogger.warning(
                  'Debug test crash triggered — intentional Crashlytics check',
                );
                FirebaseCrashlytics.instance.crash();
              },
              label: const Text('Test Crash'),
              icon: const Icon(Icons.bug_report),
              backgroundColor: AppColors.error,
            )
          : null,
    );
  }
}
