import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:mobile/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:mobile/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/features/friends/presentation/screens/friend_requests_screen.dart';
import 'package:mobile/features/friends/presentation/screens/friends_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/host_session_detail_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/member_session_detail_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/my_sessions_screen.dart';
import 'package:mobile/features/profile/presentation/screens/other_user_profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/create_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/edit_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/members_list_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/requests_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/session_detail_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:mobile/shared/widgets/main_shell.dart';
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

  // My Sessions detail routes
  static const String mySessionMember = '/my-sessions/session/:id/member';
  static const String mySessionHost = '/my-sessions/session/:id/host';

  // Session routes
  static const String sessionCreate = '/sessions/create';
  static const String sessionDetail = '/sessions/:id';
  static const String sessionEdit = '/sessions/:id/edit';
  static const String sessionMembers = '/sessions/:id/members';
  static const String sessionRequests = '/sessions/:id/requests';

  // Friends routes
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';

  // Profile routes
  static const String profile = '/profile';
  static const String profileUser = '/profile/:userId';

  // Settings
  static const String settings = '/settings';

  // Messages DM
  static const String messagesDm = '/messages/dm/:id';
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

/// Thin ConsumerWidget wrapper so [FriendRequestsScreen] can read the current
/// user's UID from Riverpod without requiring GoRouter builder callbacks to
/// receive a BuildContext that is part of a ProviderScope descendant.
///
/// UID is sourced directly from [firebaseAuthStateProvider] per ADR 0006.
/// No `userProvider` call is made here — only uid is required for this route.
class _FriendRequestsRouteWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return FriendRequestsScreen(currentUid: uid);
  }
}

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

      // ── Profile routes (push over the shell) ────────────────────────────
      GoRoute(
        path: RouteConstants.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => OtherUserProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),

      // ── Settings (stub) ─────────────────────────────────────────────────
      GoRoute(
        path: RouteConstants.settings,
        builder: (_, __) => _comingSoonScreen('Settings'),
      ),

      // ── Messages DM stub ────────────────────────────────────────────────
      GoRoute(
        path: '/messages/dm/:id',
        builder: (_, __) => _comingSoonScreen('Messages'),
      ),

      // ── Friends routes (push over the shell) ────────────────────────────
      GoRoute(
        path: RouteConstants.friends,
        builder: (_, __) => const FriendsScreen(),
        routes: [
          GoRoute(
            path: 'requests',
            builder: (context, state) {
              // UID is sourced from firebaseAuthStateProvider inside
              // _FriendRequestsRouteWrapper (a ConsumerWidget) per ADR 0006.
              return _FriendRequestsRouteWrapper();
            },
          ),
        ],
      ),

      // ── Session routes (push over the shell) ────────────────────────────
      GoRoute(
        path: RouteConstants.sessionCreate,
        builder: (_, __) => const CreateSessionScreen(),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (_, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                EditSessionScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'members',
            builder: (_, state) =>
                MembersListScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'requests',
            builder: (_, state) =>
                RequestsScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.home,
                builder: (_, __) => const HomeScreen(),
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
                builder: (_, __) => const MySessionsScreen(),
                routes: [
                  GoRoute(
                    path: 'session/:id/member',
                    builder: (_, state) => MemberSessionDetailScreen(
                      sessionId: state.pathParameters['id']!,
                      isCompleted: state.extra == true,
                    ),
                  ),
                  GoRoute(
                    path: 'session/:id/host',
                    builder: (_, state) => HostSessionDetailScreen(
                      sessionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
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
