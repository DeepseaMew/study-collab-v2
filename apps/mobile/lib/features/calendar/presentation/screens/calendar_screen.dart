import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/connectivity/connectivity_provider.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sessions_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_window_provider.dart';
import 'package:mobile/features/calendar/presentation/widgets/offline_banner.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/widgets/session_card.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<SessionEntity> _sessionsForDay(
    List<SessionEntity> all,
    DateTime day,
    String uid,
  ) {
    return all
        .where(
          (s) =>
              isSameDay(s.scheduledAt, day) &&
              (s.memberUids.contains(uid) || s.hostUid == uid),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthStateProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = authUser.uid;
    final isOnline = ref.watch(isOnlineProvider);
    final window = ref.watch(calendarWindowProvider);
    final sessionsAsync = ref.watch(
      calendarSessionsProvider(uid, window.start, window.end),
    );
    final sessions = sessionsAsync.valueOrNull ?? <SessionEntity>[];
    final selected = _selectedDay != null
        ? _sessionsForDay(sessions, _selectedDay!, uid)
        : <SessionEntity>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('Calendar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<CalendarFormat>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.secondary
                      : AppColors.surface,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.accent
                      : AppColors.hint,
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: AppColors.border),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                minimumSize: WidgetStateProperty.all(const Size(0, 44)),
              ),
              segments: const [
                ButtonSegment(
                  value: CalendarFormat.month,
                  label: Text(
                    'Month',
                    style: TextStyle(fontSize: 12),
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
                ButtonSegment(
                  value: CalendarFormat.week,
                  label: Text(
                    'Week',
                    style: TextStyle(fontSize: 12),
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
              selected: {_calendarFormat},
              onSelectionChanged: (v) {
                setState(() => _calendarFormat = v.first);
                appLogger.debug(AnalyticsEvents.calendarViewFormatToggled);
              },
              showSelectedIcon: false,
            ),
          ),
          if (FeatureFlags.gcalSyncEnabled)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Google Calendar Sync',
              onPressed: () =>
                  context.push(RouteConstants.calendarSyncSettings),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline) const OfflineBanner(),
          Container(
            color: AppColors.surface,
            child: TableCalendar<SessionEntity>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _sessionsForDay(sessions, day, uid),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                appLogger.debug(AnalyticsEvents.calendarDaySelected);
              },
              onFormatChanged: (f) => setState(() => _calendarFormat = f),
              onPageChanged: (f) {
                setState(() => _focusedDay = f);
                ref.read(calendarWindowProvider.notifier).advanceToMonth(f);
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent),
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
                outsideDaysVisible: false,
              ),
              calendarBuilders: CalendarBuilders<SessionEntity>(
                defaultBuilder: (context, day, _) {
                  final daySessions = _sessionsForDay(sessions, day, uid);
                  final hasPersonal = daySessions.isNotEmpty;
                  if (!hasPersonal) return null;
                  return Semantics(
                    label: 'Day ${day.day}, ${daySessions.length} session(s)',
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final colors = events
                      .map(
                        (s) => s.status == 'ended'
                            ? AppColors.hint
                            : AppColors.accent,
                      )
                      .toSet()
                      .take(3)
                      .toList();
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: colors
                          .map(
                            (c) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _selectedDay == null
                ? const _NoDateSelected()
                : selected.isEmpty
                ? _NoSessionsDay(date: _selectedDay!)
                : _DaySessionsPanel(
                    date: _selectedDay!,
                    sessions: selected,
                    currentUid: uid,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Inline day-session panel ──────────────────────────────────────────────────

class _DaySessionsPanel extends StatelessWidget {
  const _DaySessionsPanel({
    required this.date,
    required this.sessions,
    required this.currentUid,
  });

  final DateTime date;
  final List<SessionEntity> sessions;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = sessions.length;
    final showOverflow = n > 3;
    final displayed = sessions.take(3).toList();
    final itemCount = 1 + displayed.length + (showOverflow ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('MMMM d').format(date)} · $n sessions',
                    style: tt.bodyMedium,
                  ),
                ),
                if (showOverflow)
                  Semantics(
                    label: 'See all sessions for this day',
                    button: true,
                    excludeSemantics: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push(
                        RouteConstants.calendarDay,
                        extra: (date, sessions),
                      ),
                      child: const Text('See all →'),
                    ),
                  ),
              ],
            ),
          );
        }
        final sessionIndex = index - 1;
        if (sessionIndex < displayed.length) {
          final s = displayed[sessionIndex];
          return SessionCard(
            session: s,
            currentUserId: currentUid,
            onTap: () => _onSessionTap(context, s, currentUid),
          );
        }
        return Semantics(
          label: 'Show ${n - 3} more sessions',
          button: true,
          child: GestureDetector(
            onTap: () => context.push(
              RouteConstants.calendarDay,
              extra: (date, sessions),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '+ ${n - 3} more sessions — see all',
                style: tt.labelLarge?.copyWith(color: const Color(0xFF5186CD)),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSessionTap(BuildContext context, SessionEntity session, String uid) {
    appLogger.debug(AnalyticsEvents.calendarSessionTapped);
    if (session.hostUid == uid) {
      context.push('/my-sessions/session/${session.sessionId}/host');
    } else {
      context.push('/my-sessions/session/${session.sessionId}/member');
    }
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _NoDateSelected extends StatelessWidget {
  const _NoDateSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.touch_app_outlined,
              size: 52,
              color: AppColors.disabled,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap a day to see sessions',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

class _NoSessionsDay extends StatelessWidget {
  const _NoSessionsDay({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.event_busy_outlined,
              size: 52,
              color: AppColors.disabled,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No sessions on ${DateFormat('MMMM d').format(date)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}
