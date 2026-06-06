import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/avatar_widget.dart';

/// Settings screen (ADR 0013).
///
/// Sections:
/// 1. Profile — avatar, display name, email (read-only, no Edit Profile action)
/// 2. Notifications — 4 toggles (All Notifications, Join Request Alerts,
///    Friend Requests, Rating Available)
/// 3. Account — Sign Out (with confirmation dialog)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final userAsync = ref.watch(userProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, st) {
          appLogger.error(
            'SettingsScreen: failed to load user',
            exception: e,
            stackTrace: st,
          );
          return const Center(child: Text('Failed to load settings'));
        },
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _SettingsBody(uid: uid, user: user);
        },
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.uid, required this.user});

  final String uid;
  final dynamic user; // UserEntity

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final prefsAsync = ref.watch(notificationPreferencesNotifierProvider);
    final prefs =
        prefsAsync.valueOrNull ??
        <String, bool>{
          'allNotifications': true,
          'joinRequestAlerts': true,
          'friendRequests': true,
          'ratingAvailable': true,
        };

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
      children: [
        // ── Profile section ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Profile',
            style: tt.labelLarge?.copyWith(color: AppColors.hint),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                AvatarWidget(
                  photoUrl: user.photoUrl as String?,
                  displayName: user.displayName as String,
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName as String,
                        style: tt.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email as String,
                        style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Notifications section ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Notifications',
            style: tt.labelLarge?.copyWith(color: AppColors.hint),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: [
              _PrefToggleTile(
                title: 'All Notifications',
                prefKey: 'allNotifications',
                value: prefs['allNotifications'] ?? true,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _PrefToggleTile(
                title: 'Join Request Alerts',
                prefKey: 'joinRequestAlerts',
                value: prefs['joinRequestAlerts'] ?? true,
                enabled: prefs['allNotifications'] ?? true,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _PrefToggleTile(
                title: 'Friend Requests',
                prefKey: 'friendRequests',
                value: prefs['friendRequests'] ?? true,
                enabled: prefs['allNotifications'] ?? true,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _PrefToggleTile(
                title: 'Rating Available',
                prefKey: 'ratingAvailable',
                value: prefs['ratingAvailable'] ?? true,
                enabled: prefs['allNotifications'] ?? true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Account section ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Account',
            style: tt.labelLarge?.copyWith(color: AppColors.hint),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: [
              Semantics(
                label: 'Sign Out',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.hint),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(authStateNotifierProvider.notifier).signOut();
      appLogger.info(AnalyticsEvents.authSignOut);
    } catch (e, st) {
      appLogger.error(
        'SettingsScreen: sign out failed',
        exception: e,
        stackTrace: st,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign out failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// A switch list tile bound to a single notification preference key.
class _PrefToggleTile extends ConsumerWidget {
  const _PrefToggleTile({
    required this.title,
    required this.prefKey,
    required this.value,
    this.enabled = true,
  });

  final String title;
  final String prefKey;
  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label:
          '$title toggle, ${value ? "on" : "off"}${enabled ? "" : ", disabled"}',
      child: SwitchListTile(
        title: Text(
          title,
          style: tt.bodyMedium?.copyWith(
            color: enabled ? AppColors.text : AppColors.disabled,
          ),
        ),
        value: value,
        onChanged: enabled
            ? (v) => ref
                  .read(notificationPreferencesNotifierProvider.notifier)
                  .toggle(prefKey, value: v)
            : null,
        activeThumbColor: AppColors.accent,
      ),
    );
  }
}
