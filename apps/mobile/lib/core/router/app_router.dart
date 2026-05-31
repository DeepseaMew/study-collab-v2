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
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_day_screen.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_sync_settings_screen.dart';
import 'package:mobile/features/friends/presentation/screens/friend_requests_screen.dart';
import 'package:mobile/features/friends/presentation/screens/friends_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/host_session_detail_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/member_session_detail_screen.dart';
import 'package:mobile/features/my_sessions/presentation/screens/my_sessions_screen.dart';
import 'package:mobile/features/chat/presentation/screens/dm_conversation_list_screen.dart';
import 'package:mobile/features/chat/presentation/screens/dm_message_screen.dart';
import 'package:mobile/features/chat/presentation/screens/session_chat_screen.dart';
import 'package:mobile/features/note_sharing/presentation/screens/all_files_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_panel_screen.dart';
import 'package:mobile/features/profile/presentation/screens/other_user_profile_screen.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:mobile/features/search/presentation/screens/search_screen.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/screens/create_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/edit_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/members_list_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/requests_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/session_detail_screen.dart';
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

  // Note-sharing routes (ADR 0008)
  static const String sessionFiles = '/my-sessions/session/:id/files';

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

  // Notifications
  static const String notifications = '/notifications';

  // Messages DM
  static const String messagesDm = '/messages/dm/:id';

  // Session (group) chat (ADR 0012)
  static const String sessionChat = '/sessions/:sessionId/chat';

  // Calendar sub-routes
  static const String calendarDay = '/calendar/day';
  static const String calendarSyncSettings = '/calendar/sync-settings';

  // Search route (ADR 0010)
  static const String search = '/search';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FriendRequestsScreen(currentUid: uid);
  }
}

/// Thin ConsumerWidget wrapper so [NotificationPanelScreen] can read the
/// current user's UID from Riverpod without GoRouter builder callbacks needing
/// a ProviderScope descendant [BuildContext].
class _NotificationPanelRouteWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return NotificationPanelScreen(uid: uid);
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
        builder: (_, state) =>
            OtherUserProfileScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Settings ────────────────────────────────────────────────────────
      GoRoute(
        path: RouteConstants.settings,
        builder: (_, __) => const SettingsScreen(),
      ),

      // ── Notifications (ADR 0013) ─────────────────────────────────────────
      GoRoute(
        path: RouteConstants.notifications,
        builder: (_, __) {
          // UID is sourced inside the screen from firebaseAuthStateProvider.
          return _NotificationPanelRouteWrapper();
        },
      ),

      // ── Messages DM ─────────────────────────────────────────────────────
      GoRoute(
        path: '/messages/dm/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DmMessageScreen(
            dmId: state.pathParameters['id']!,
            otherUid: (extra?['otherUid'] as String?) ?? '',
            displayName: (extra?['displayName'] as String?) ?? '',
          );
        },
      ),

      // ── Session (group) chat (ADR 0012) ─────────────────────────────────
      GoRoute(
        path: '/sessions/:sessionId/chat',
        builder: (_, state) =>
            SessionChatScreen(sessionId: state.pathParameters['sessionId']!),
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
      // Top-level so pushing /sessions/:id/edit does not insert
      // SessionDetailScreen as an intermediate stack entry.
      GoRoute(
        path: '/sessions/:id/edit',
        builder: (_, state) =>
            EditSessionScreen(sessionId: state.pathParameters['id']!),
      ),

      // ── Search route (ADR 0010) ─────────────────────────────────────────
      GoRoute(
        path: RouteConstants.search,
        builder: (_, __) => const SearchScreen(),
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
                builder: (_, __) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'day',
                    builder: (context, state) {
                      final extra =
                          state.extra! as (DateTime, List<SessionEntity>);
                      return CalendarDayScreen(
                        day: extra.$1,
                        sessions: extra.$2,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'sync-settings',
                    redirect: (_, __) => FeatureFlags.gcalSyncEnabled
                        ? null
                        : RouteConstants.calendar,
                    builder: (context, state) =>
                        const CalendarSyncSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteConstants.messages,
                builder: (_, __) => const DmConversationListScreen(),
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
                    builder: (_, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final isCompleted =
                          (extra?['isCompleted'] as bool?) ?? false;
                      final initialTabIndex =
                          (extra?['initialTabIndex'] as int?) ?? 0;
                      return MemberSessionDetailScreen(
                        sessionId: state.pathParameters['id']!,
                        isCompleted: isCompleted,
                        initialTabIndex: initialTabIndex,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'session/:id/host',
                    builder: (_, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final initialTabIndex =
                          (extra?['initialTabIndex'] as int?) ?? 0;
                      return HostSessionDetailScreen(
                        sessionId: state.pathParameters['id']!,
                        initialTabIndex: initialTabIndex,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'session/:id/files',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      if (extra == null) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return AllFilesScreen(
                        sessionId: extra['sessionId'] as String,
                        currentUserId: extra['currentUserId'] as String,
                        hostUid: extra['hostUid'] as String,
                      );
                    },
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
