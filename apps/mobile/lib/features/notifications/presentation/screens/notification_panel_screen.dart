import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/features/notifications/presentation/widgets/notification_list_tile.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Full-screen notification panel (ADR 0013).
///
/// - Calls [markAllRead] on init via [initState].
/// - Filters the notification list by the user's local preference map.
/// - Capped at 50 documents from the stream.
/// - Shows an empty state when no notifications match the current filter.
class NotificationPanelScreen extends ConsumerStatefulWidget {
  const NotificationPanelScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<NotificationPanelScreen> createState() =>
      _NotificationPanelScreenState();
}

class _NotificationPanelScreenState
    extends ConsumerState<NotificationPanelScreen> {
  @override
  void initState() {
    super.initState();
    appLogger.info(AnalyticsEvents.notificationPanelOpened);
    // Fire-and-forget: mark all read on open (ADR 0013 SD5).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllRead();
    });
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(widget.uid);
    } catch (e, st) {
      appLogger.error(
        'NotificationPanelScreen: markAllRead failed',
        exception: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final notificationsAsync = ref.watch(notificationsProvider(widget.uid));
    final prefsAsync = ref.watch(notificationPreferencesNotifierProvider);

    final prefs =
        prefsAsync.valueOrNull ??
        <String, bool>{
          'allNotifications': true,
          'joinRequestAlerts': true,
          'friendRequests': true,
          'ratingAvailable': true,
        };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          appLogger.error(
            'NotificationPanelScreen: stream error',
            exception: e,
            stackTrace: st,
          );
          return Center(
            child: Text('Failed to load notifications', style: tt.bodyMedium),
          );
        },
        data: (notifications) {
          final filtered = _applyPreferenceFilter(notifications, prefs);
          if (filtered.isEmpty) {
            return _EmptyState(tt: tt);
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) =>
                NotificationListTile(notification: filtered[i]),
          );
        },
      ),
    );
  }

  /// Applies client-side preference filtering (ADR 0013 SD6).
  ///
  /// If `allNotifications` is false, nothing is shown. Otherwise, each
  /// preference key gates its corresponding notification types.
  List<NotificationEntity> _applyPreferenceFilter(
    List<NotificationEntity> all,
    Map<String, bool> prefs,
  ) {
    if (!(prefs['allNotifications'] ?? true)) return const [];
    return all.where((n) {
      return switch (n.type) {
        NotificationType.joinRequest ||
        NotificationType.joinApproved ||
        NotificationType.joinDeclined => prefs['joinRequestAlerts'] ?? true,
        NotificationType.friendRequest ||
        NotificationType.friendAccepted => prefs['friendRequests'] ?? true,
        NotificationType.ratingAvailable => prefs['ratingAvailable'] ?? true,
      };
    }).toList();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tt});

  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: AppColors.disabled,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: tt.titleMedium?.copyWith(color: AppColors.hint),
          ),
          const SizedBox(height: 8),
          Text(
            "Activity from friends and sessions\nwill appear here.",
            style: tt.bodyMedium?.copyWith(color: AppColors.hint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
