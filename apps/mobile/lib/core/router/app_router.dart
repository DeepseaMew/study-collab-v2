import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:mobile/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:mobile/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/shared/screens/home_placeholder_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

abstract final class RouteConstants {
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String verifyEmail = '/verify-email';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String calendar = '/calendar';
  static const String messages = '/messages';
  static const String mySessions = '/my-sessions';
}

// ── Router change notifier ────────────────────────────────────────────────────
//
// Bridges Riverpod auth state into GoRouter's refreshListenable so the
// redirect callback fires whenever auth state changes.

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(
      authStateNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateNotifierProvider);

    if (authAsync.isLoading) return null;

    final authState = authAsync.valueOrNull;
    if (authState == null) return RouteConstants.signIn;

    final path = state.matchedLocation;

    return switch (authState) {
      Unauthenticated() => _guardUnauthenticated(path),
      Unverified() => _guardUnverified(path),
      PendingProfileSetup() => _guardPendingSetup(path),
      Authenticated() => _guardAuthenticated(path),
    };
  }

  String? _guardUnauthenticated(String path) {
    const allowed = {RouteConstants.signIn, RouteConstants.signUp};
    return allowed.contains(path) ? null : RouteConstants.signIn;
  }

  String? _guardUnverified(String path) =>
      path == RouteConstants.verifyEmail ? null : RouteConstants.verifyEmail;

  String? _guardPendingSetup(String path) =>
      path == RouteConstants.profileSetup ? null : RouteConstants.profileSetup;

  String? _guardAuthenticated(String path) {
    const authOnlyPaths = {
      RouteConstants.signIn,
      RouteConstants.signUp,
      RouteConstants.verifyEmail,
      RouteConstants.profileSetup,
    };
    return authOnlyPaths.contains(path) ? RouteConstants.home : null;
  }
}

// ── Bottom navigation shell ───────────────────────────────────────────────────

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.secondary,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(
              Icons.calendar_month_rounded,
              color: AppColors.accent,
            ),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(
              Icons.chat_bubble_rounded,
              color: AppColors.accent,
            ),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded, color: AppColors.accent),
            label: 'My Sessions',
          ),
        ],
      ),
    );
  }
}

Widget _comingSoonScreen(String label) => Scaffold(
  body: Center(
    child: Text(
      'Coming soon',
      style: AppTypography.textTheme.displaySmall?.copyWith(
        color: AppColors.hint,
      ),
    ),
  ),
);

// ── Router provider ───────────────────────────────────────────────────────────

@riverpod
GoRouter router(RouterRef ref) {
  final notifier = _RouterNotifier(ref);

  final goRouter = GoRouter(
    initialLocation: RouteConstants.signIn,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: RouteConstants.signIn,
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: RouteConstants.signUp,
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouteConstants.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: RouteConstants.profileSetup,
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.home,
                builder: (_, __) => const HomePlaceholderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.calendar,
                // TODO(calendar-adr): replace when Calendar ADR is accepted.
                builder: (_, __) => _comingSoonScreen('Calendar'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.messages,
                // TODO(messages-adr): replace when Messages ADR is accepted.
                builder: (_, __) => _comingSoonScreen('Messages'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.mySessions,
                // TODO(sessions-adr): replace when Sessions ADR is accepted.
                builder: (_, __) => _comingSoonScreen('My Sessions'),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(goRouter.dispose);
  return goRouter;
}
