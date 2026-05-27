import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/rating_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_provider.dart';
import 'package:mobile/features/rating/presentation/providers/session_ratings_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Bottom sheet for rating session members after a session ends.
///
/// Must be wrapped in the app's [ProviderScope].
/// Pops itself when the feature flag is disabled or the user has already rated.
class RatingBottomSheet extends ConsumerStatefulWidget {
  const RatingBottomSheet({
    super.key,
    required this.sessionId,
    required this.members,
    required this.currentUserId,
    required this.hostUid,
  });

  final String sessionId;
  final List<UserEntity> members;
  final String currentUserId;
  final String hostUid;

  @override
  ConsumerState<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends ConsumerState<RatingBottomSheet> {
  final Map<String, bool> _selected = {};
  String _search = '';

  List<UserEntity> get _rateable =>
      widget.members.where((m) => m.uid != widget.currentUserId).toList();

  List<UserEntity> _filterBySearch(List<UserEntity> members) {
    final q = _search.toLowerCase();
    if (q.isEmpty) return members;
    return members
        .where((m) => m.displayName.toLowerCase().contains(q))
        .toList();
  }

  String _errorMessage(RatingError e) => switch (e) {
    RatingSelfRatingNotAllowed() => 'You cannot rate yourself.',
    RatingSessionNotEnded() =>
      'Rating is only available after the session ends.',
    RatingAlreadyRated() =>
      'You have already rated the members of this session.',
    RatingSubmitFailed(message: final msg) when msg == 'rating_disabled' =>
      'Rating is not available right now.',
    RatingSubmitFailed(message: final msg) when msg == 'permission_denied' =>
      'You do not have permission to submit ratings.',
    RatingSubmitFailed() => 'Could not submit ratings. Please try again.',
    RatingOfflineNotSupported() =>
      'Rating requires an internet connection. Please try again.',
    RatingRateeNotMember() =>
      'One or more selected members are not in this session.',
  };

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(ratingEnabledProvider);
    final hasRatedAsync = ref.watch(
      hasRatedProvider(widget.sessionId, widget.currentUserId),
    );

    // Close with a success message the moment submit transitions loading → data.
    ref.listen<AsyncValue<void>>(ratingNotifierProvider(widget.sessionId), (
      prev,
      next,
    ) {
      if (prev is AsyncLoading && next is AsyncData) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ratings submitted! Thanks for your feedback.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    });

    if (!isEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating is not available right now.')),
          );
        }
      });
      return const SizedBox.shrink();
    }

    final hasRated = hasRatedAsync.valueOrNull ?? false;
    if (hasRated) {
      // Defensive: sheet was opened while already rated (banner prevents this
      // in normal flow). Pop silently — no snackbar needed here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final ratingState = ref.watch(ratingNotifierProvider(widget.sessionId));
    final isLoading = ratingState is AsyncLoading;
    final ratingError = ratingState is AsyncError ? ratingState.error : null;

    // Determine which rateable members the current user has already rated.
    final ratingsAsync = ref.watch(sessionRatingsProvider(widget.sessionId));
    final alreadyRatedUids =
        ratingsAsync.valueOrNull
            ?.where((r) => r.raterUid == widget.currentUserId)
            .map((r) => r.rateeUid)
            .toSet() ??
        const <String>{};

    // Split into unvoted (interactive, shown first) and voted (disabled, shown below).
    final unvoted = _filterBySearch(
      _rateable.where((m) => !alreadyRatedUids.contains(m.uid)).toList(),
    );
    final voted = _filterBySearch(
      _rateable.where((m) => alreadyRatedUids.contains(m.uid)).toList(),
    );
    final allVisible = [...unvoted, ...voted];

    final selectedUids = _selected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final canSubmit = selectedUids.isNotEmpty && !isLoading;

    final mq = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // viewInsets.bottom = keyboard height
      // padding.bottom    = device safe area (home indicator)
      // kBottomNavigationBarHeight = app nav bar
      padding: EdgeInsets.only(
        bottom:
            mq.viewInsets.bottom +
            mq.padding.bottom +
            kBottomNavigationBarHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rate Session Members',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Close rating',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.hint),
                    onPressed: isLoading
                        ? null
                        : () {
                            appLogger.debug(AnalyticsEvents.ratingSkipped);
                            Navigator.pop(context);
                          },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Give a thumbs-up to members who made this session great.',
                style: TextStyle(color: AppColors.hint, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            // Search field
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search members by name',
                prefixIcon: const Icon(
                  Icons.search_outlined,
                  color: AppColors.hint,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Member list — unvoted (interactive) first, already-voted (disabled) below
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.3),
              child: allVisible.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No members found.',
                        style: TextStyle(color: AppColors.hint, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: allVisible.length,
                      itemBuilder: (_, i) {
                        final m = allVisible[i];
                        final isAlreadyVoted = alreadyRatedUids.contains(m.uid);
                        final isHost = m.uid == widget.hostUid;
                        final liked = _selected[m.uid] ?? false;

                        return Opacity(
                          opacity: isAlreadyVoted ? 0.45 : 1.0,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _MemberAvatar(
                              displayName: m.displayName,
                              photoUrl: m.photoUrl,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  m.displayName,
                                  style: TextStyle(
                                    color: isAlreadyVoted
                                        ? AppColors.hint
                                        : AppColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isHost) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Host',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: isAlreadyVoted
                                ? const Text(
                                    'Rated',
                                    style: TextStyle(
                                      color: AppColors.hint,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: SizedBox(
                              width: 44,
                              height: 44,
                              child: isAlreadyVoted
                                  ? Semantics(
                                      label: 'Already rated ${m.displayName}',
                                      child: const Icon(
                                        Icons.thumb_up,
                                        color: AppColors.hint,
                                        size: 20,
                                      ),
                                    )
                                  : Semantics(
                                      label: 'Rate ${m.displayName}',
                                      button: true,
                                      child: IconButton(
                                        icon: Icon(
                                          liked
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_outlined,
                                          color: liked
                                              ? AppColors.accent
                                              : AppColors.hint,
                                        ),
                                        onPressed: () => setState(
                                          () => _selected[m.uid] = !liked,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Error message
            if (ratingError != null && ratingError is RatingError) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage(ratingError),
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: canSubmit
                        ? () => ref
                              .read(
                                ratingNotifierProvider(
                                  widget.sessionId,
                                ).notifier,
                              )
                              .submitRatings(
                                selectedUids,
                                widget.members.map((m) => m.uid).toList(),
                              )
                        : null,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          appLogger.debug(AnalyticsEvents.ratingSkipped);
                          Navigator.pop(context);
                        },
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
        backgroundColor: AppColors.secondary,
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.secondary,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
