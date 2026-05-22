import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sync_provider.dart';
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
        body: const Center(
          child: Text('Coming soon'),
        ),
      );
    }

    final syncState = ref.watch(calendarSyncNotifierProvider);
    final tt = Theme.of(context).textTheme;
    final lastSynced = syncState.valueOrNull?.syncedAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Google Calendar Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Connection status ──────────────────────────────────────────────
          _ConnectionStatusTile(syncState: syncState),
          const SizedBox(height: 16),

          // ── Error banner ───────────────────────────────────────────────────
          if (syncState.hasError) ...[
            _ErrorBanner(error: syncState.error),
            const SizedBox(height: 16),
          ],

          // ── Last sync timestamp ────────────────────────────────────────────
          if (lastSynced != null)
            Text(
              'Last synced: ${DateFormat('d MMM yyyy, HH:mm').format(lastSynced)}',
              style: tt.bodySmall?.copyWith(color: AppColors.hint),
            ),
          const SizedBox(height: 24),

          // ── Connect button ────────────────────────────────────────────────
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
              icon: syncState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: const Text('Connect Google Calendar'),
              onPressed: syncState.isLoading
                  ? null
                  : () {
                      ref.read(calendarSyncNotifierProvider.notifier).connect();
                      appLogger.info(
                        'gcal_sync: connect button tapped',
                      );
                    },
            ),
          ),
          const SizedBox(height: 12),

          // ── Disconnect button ─────────────────────────────────────────────
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
              onPressed: syncState.isLoading
                  ? null
                  : () {
                      ref
                          .read(calendarSyncNotifierProvider.notifier)
                          .disconnect();
                      appLogger.info('gcal_sync: disconnect button tapped');
                    },
            ),
          ),
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.text),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
