import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

/// Temporary home screen — replaced when the Home feature ADR lands.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Home',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: AppColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authStateNotifierProvider.notifier).signOut(),
            child: Text(
              'Sign out',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Home',
          style: AppTypography.textTheme.displayLarge?.copyWith(
            color: AppColors.text,
          ),
        ),
      ),
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: () {
                appLogger.warning(
                  'Debug test crash triggered — intentional Crashlytics check',
                );
                // ignore: avoid_dynamic_calls
                throw Exception('Test crash');
              },
              label: const Text('Test Crash'),
              icon: const Icon(Icons.bug_report),
              backgroundColor: AppColors.error,
            )
          : null,
    );
  }
}
