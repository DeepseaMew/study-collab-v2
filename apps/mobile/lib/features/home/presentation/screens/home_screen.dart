import 'dart:math' show max, min;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/pin_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/avatar_widget.dart';
import 'package:mobile/shared/widgets/session_card.dart';

/// The main home screen shown in the first shell branch.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthStateProvider).valueOrNull?.uid;
    final user = uid != null ? ref.watch(userProvider(uid)).valueOrNull : null;

    final firstName = user?.displayName.split(' ').first ?? 'Student';
    final avatarUrl = user?.photoUrl;

    return _HomeBody(firstName: firstName, avatarUrl: avatarUrl, uid: uid);
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({
    required this.firstName,
    required this.avatarUrl,
    required this.uid,
  });

  final String firstName;
  final String? avatarUrl;
  final String? uid;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  bool _pinLoading = false;
  int _page = 0;
  static const _kPageSize = 4;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _onRefresh() async {}

  void _openSearch(BuildContext context) {
    context.push(RouteConstants.search);
  }

  Future<void> _joinWithPin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinEntryDialog(),
    );
    if (pin == null || pin.isEmpty || !mounted) return;
    setState(() => _pinLoading = true);
    try {
      final session = await ref
          .read(sessionRepositoryProvider)
          .findSessionByPin(pin);
      if (!mounted) return;
      if (session == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No session found with that PIN')),
        );
      } else {
        ref.read(joinPinProvider.notifier).state = pin;
        await router.push(
          RouteConstants.sessionDetail.replaceFirst(':id', session.sessionId),
        );
      }
    } catch (e, st) {
      appLogger.error('findSessionByPin failed', exception: e, stackTrace: st);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _pinLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sessionsAsync = ref.watch(publicSessionsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_greeting()}, ${widget.firstName} 👋',
              style: tt.displaySmall,
            ),
            Text(
              'Find your next study session',
              style: tt.bodyMedium?.copyWith(color: AppColors.hint),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: 'Go to profile',
            button: true,
            child: GestureDetector(
              onTap: () => context.push(RouteConstants.profile),
              child: AvatarWidget(
                photoUrl: widget.avatarUrl,
                displayName: widget.firstName,
                radius: 17,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.notifications_outlined),
              // TODO(notifications-adr): wire when Notifications feature lands
              onPressed: null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Fake search bar — taps show snackbar (search feature not yet landed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GestureDetector(
              onTap: () => _openSearch(context),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.hint, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Search sessions, #hashtags, @hosts...',
                        style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
                onPressed: _pinLoading ? null : () => _joinWithPin(context),
                icon: _pinLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.lock_outline, size: 16),
                label: const Text('Join with PIN'),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.accent,
              child: sessionsAsync.when(
                loading: () => const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                ),
                error: (_, __) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text(
                        'Failed to load sessions',
                        style: tt.bodyMedium,
                      ),
                    ),
                  ),
                ),
                data: (sessions) {
                  final now = DateTime.now();
                  final filtered = sessions
                      .where(
                        (s) =>
                            s.status == 'scheduled' &&
                            (s.scheduledEndAt == null ||
                                s.scheduledEndAt!.isAfter(now)),
                      )
                      .where(
                        (s) =>
                            widget.uid == null ||
                            !s.memberUids.contains(widget.uid),
                      )
                      .toList();
                  if (filtered.isEmpty) return const _EmptyState();
                  if (_page * _kPageSize >= filtered.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _page = 0);
                    });
                  }
                  final totalPages = max(
                    1,
                    (filtered.length / _kPageSize).ceil(),
                  );
                  final pageItems = filtered.sublist(
                    _page * _kPageSize,
                    min((_page + 1) * _kPageSize, filtered.length),
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16, 8, 16, 88,
                    ),
                    itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == pageItems.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _page > 0
                                    ? () => setState(() => _page--)
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_left,
                                  size: 18,
                                ),
                                label: const Text('Prev'),
                              ),
                              Text(
                                '${_page + 1} / $totalPages',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.hint,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _page < totalPages - 1
                                    ? () => setState(() => _page++)
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                ),
                                label: const Text('Next'),
                              ),
                            ],
                          ),
                        );
                      }
                      final session = pageItems[i];
                      final isPending =
                          ref
                              .watch(
                                myPendingRequestProvider(
                                  session.sessionId,
                                  widget.uid ?? '',
                                ),
                              )
                              .valueOrNull ??
                          false;
                      return SessionCard(
                        session: session,
                        currentUserId: widget.uid ?? '',
                        isPending: isPending,
                        onTap: () => context.push(
                          RouteConstants.sessionDetail.replaceFirst(
                            ':id',
                            session.sessionId,
                          ),
                        ),
                        showJoinButton: true,
                        onJoinTap: isPending
                            ? null
                            : () => context.push(
                                RouteConstants.sessionDetail.replaceFirst(
                                  ':id',
                                  session.sessionId,
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // Debug-only test crash FAB — verifies Crashlytics is receiving data.
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () {
                appLogger.warning(
                  'Debug test crash triggered — intentional Crashlytics check',
                );
                FirebaseCrashlytics.instance.crash();
              },
              label: const Text('Test Crash'),
              icon: const Icon(Icons.bug_report),
              backgroundColor: AppColors.error,
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text('All caught up!', style: tt.displaySmall),
              const SizedBox(height: 8),
              Text(
                "You've joined all available sessions.\nCreate one or check back later!",
                style: tt.bodyMedium?.copyWith(color: AppColors.hint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog();

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Enter Session PIN',
        style: TextStyle(color: AppColors.text, fontSize: 16),
      ),
      content: TextField(
        controller: _ctrl,
        obscureText: _obscure,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'PIN',
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppColors.hint,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.hint)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Join'),
        ),
      ],
    );
  }
}
