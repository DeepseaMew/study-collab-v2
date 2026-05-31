import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A bell icon with an unread-count badge (ADR 0013).
///
/// Taps navigate to `/notifications`. [uid] must be the current user's UID.
/// No PII is stored or logged inside this widget.
class NotificationBellBadge extends ConsumerWidget {
  const NotificationBellBadge({super.key, required this.uid});

  /// The current user's UID. Must not be empty.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider(uid));
    final count = countAsync.valueOrNull ?? 0;
    final showBadge = count > 0;

    return Semantics(
      label: showBadge
          ? 'Notifications, $count unread'
          : 'Notifications, no unread',
      button: true,
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined),
            if (showBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => context.push(RouteConstants.notifications),
      ),
    );
  }
}
