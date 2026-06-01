import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_bottom_sheet.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A persistent banner prompting the user to rate their session members.
///
/// Hides itself when the feature flag is disabled, the user has already rated,
/// or while loading. The parent screen passes [members] and [hostUid] down.
class RatingBannerWidget extends ConsumerWidget {
  const RatingBannerWidget({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    required this.members,
    required this.hostUid,
    required this.sessionStatus,
  });

  final String sessionId;
  final String currentUserId;
  final List<UserEntity> members;
  final String hostUid;
  final String sessionStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessionStatus != 'ended') return const SizedBox.shrink();

    final isEnabled = ref.watch(ratingEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final hasRatedAsync = ref.watch(hasRatedProvider(sessionId, currentUserId));

    return hasRatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hasRated) {
        if (hasRated) return const SizedBox.shrink();

        return Semantics(
          label: 'Rate your session members banner',
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_outlined,
                      color: AppColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Rate your session members',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        appLogger.debug(AnalyticsEvents.ratingBannerTapped);
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => RatingBottomSheet(
                            sessionId: sessionId,
                            members: members,
                            currentUserId: currentUserId,
                            hostUid: hostUid,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        'Rate Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
