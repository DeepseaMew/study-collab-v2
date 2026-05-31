import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sessions_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sync_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_window_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Google Calendar sync settings screen.
///
/// When [FeatureFlags.gcalSyncEnabled] is false the screen shows a
/// "Coming soon" placeholder — the sync UI is only rendered when the flag
/// is enabled.
class CalendarSyncSettingsScreen extends ConsumerWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.gcalSyncEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Google Calendar Sync')),
        body: const Center(child: Text('Coming soon')),
      );
    }

    final syncState = ref.watch(calendarSyncNotifierProvider);
    final tt = Theme.of(context).textTheme;
    final lastSynced = syncState.valueOrNull?.syncedAt;
    // isConnected = we have a SyncResult (non-null value), meaning at least one
    // successful sync has completed. AsyncData(null) means disconnected.
    final isConnected = syncState.valueOrNull != null;

    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
    final window = ref.watch(calendarWindowProvider);
    final sessions =
        ref
            .watch(calendarSessionsProvider(uid, window.start, window.end))
            .valueOrNull ??
        const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Google Calendar Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Connection status ──────────────────────────────────────────────
          _ConnectionStatusTile(syncState: syncState),
          const SizedBox(height: 16),

          // ── While loading: status tile is sufficient — no buttons ──────────
          if (syncState.isLoading) ...[
            // intentionally empty: _ConnectionStatusTile shows "Syncing…"
          ] else if (isConnected) ...[
            // ── Connected: show last sync timestamp + Disconnect button ───────
            if (lastSynced != null) ...[
              Text(
                'Last synced: ${DateFormat('d MMM yyyy, HH:mm').format(lastSynced)}',
                style: tt.bodySmall?.copyWith(color: AppColors.hint),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
                onPressed: () {
                  ref
                      .read(calendarSyncNotifierProvider.notifier)
                      .disconnect();
                  appLogger.info('gcal_sync: disconnect button tapped');
                },
              ),
            ),
          ] else ...[
            // ── Disconnected: show error banner (if any) + Connect button ─────
            if (syncState.hasError) ...[
              _ErrorBanner(error: syncState.error),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.link),
                label: const Text('Connect Google Calendar'),
                onPressed: () {
                  ref
                      .read(calendarSyncNotifierProvider.notifier)
                      .connect(sessions);
                  appLogger.info('gcal_sync: connect button tapped');
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Connection status tile ────────────────────────────────────────────────────

class _ConnectionStatusTile extends StatelessWidget {
  const _ConnectionStatusTile({required this.syncState});

  final AsyncValue<dynamic> syncState;

  @override
  Widget build(BuildContext context) {
    final isLoading = syncState.isLoading;
    return Row(
      children: [
        Icon(
          isLoading ? Icons.sync : Icons.check_circle_outline,
          color: isLoading ? AppColors.hint : AppColors.success,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isLoading ? 'Syncing…' : 'Ready',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.text),
        ),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      EmailMismatchError() =>
        'The Google account email does not match your KMUTT account. '
            'Please sign in with the same email address.',
      ApiFailureError() =>
        'A Google Calendar error occurred. Please try again.',
      CancelledError() => 'Sign-in was cancelled.',
      _ => 'An unexpected error occurred. Please try again.',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
