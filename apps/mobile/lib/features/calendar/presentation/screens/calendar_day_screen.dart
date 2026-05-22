import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/session_card.dart';

/// Full-day session list screen — pushed from [CalendarScreen] when a day
/// has more than 3 sessions. Receives [day] and [sessions] via GoRouter extra.
class CalendarDayScreen extends StatelessWidget {
  const CalendarDayScreen({
    super.key,
    required this.day,
    required this.sessions,
  });

  final DateTime day;

  /// Sessions already sorted by [scheduledAt] ascending.
  final List<SessionEntity> sessions;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = sessions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar',
              style: tt.labelSmall?.copyWith(color: AppColors.hint),
            ),
            Text(
              '${DateFormat('MMMM d').format(day)} — All Sessions',
              style: tt.titleLarge,
            ),
          ],
        ),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final uid =
              ref.watch(firebaseAuthStateProvider).valueOrNull?.uid ?? '';
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: n + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$n sessions · sorted by start time',
                    style: tt.labelSmall?.copyWith(color: AppColors.hint),
                  ),
                );
              }
              final s = sessions[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  label: 'Session: ${s.title}',
                  child: SessionCard(
                    session: s,
                    currentUserId: uid,
                    onTap: () => _onSessionTap(context, s, uid),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onSessionTap(
    BuildContext context,
    SessionEntity session,
    String uid,
  ) {
    appLogger.debug(AnalyticsEvents.calendarSessionTapped);
    if (session.hostUid == uid) {
      context.push('/my-sessions/session/${session.sessionId}/host');
    } else {
      context.push('/my-sessions/session/${session.sessionId}/member');
    }
  }
}
