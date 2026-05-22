// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// // Field notes:
// //   old Session.startTime        → SessionEntity.scheduledAt (.toDate() for DateTime)
// //   old JoinStatus.joined/.host  → session.memberUids.contains(uid) / session.hostUid == uid
// //   old s.subject.color          → no Subject enum in new stack (ADR 0003);
// //                                   derive marker color from session.status:
// //                                     'scheduled'/'active' → AppColors.accent  #894DEF
// //                                     'ended'              → AppColors.hint    #767676
// //
// // CalendarWindowNotifier (ADR 0007) manages windowStart/windowEnd.
// // onPageChanged must call ref.read(calendarWindowProvider.notifier).advanceToMonth(f).
// // Rebuild as ConsumerStatefulWidget using package:mobile/... imports.

// class CalendarScreen extends ConsumerStatefulWidget {
//   const CalendarScreen({super.key});

//   @override
//   ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
// }

// class _CalendarScreenState extends ConsumerState<CalendarScreen> {
//   CalendarFormat _calendarFormat = CalendarFormat.month;
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;

//   // [filter sessions by scheduledAt date; old used isSameDay(s.startTime, day)]
//   List<Object> _sessionsForDay(List<Object> all, DateTime day) =>
//       // [all.where((s) => isSameDay(s.scheduledAt.toDate(), day)).toList()]
//       [];

//   @override
//   Widget build(BuildContext context) {
//     // [watch calendarSessionsProvider(uid, windowStart, windowEnd) → List<SessionEntity>]
//     // [window bounds: ref.watch(calendarWindowProvider)]
//     final List<Object> sessions = []; // [placeholder — replace with provider watch]

//     final selected = _selectedDay != null
//         ? _sessionsForDay(sessions, _selectedDay!)
//         : <Object>[];

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         titleSpacing: 20,
//         title: const Text('Calendar'),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: SegmentedButton<CalendarFormat>(
//               style: ButtonStyle(
//                 backgroundColor: WidgetStateProperty.resolveWith(
//                   (s) => s.contains(WidgetState.selected)
//                       // AppColors.secondary — #EDE9FE
//                       ? const Color(0xFFEDE9FE)
//                       // AppColors.surface — #F8F7FF
//                       : const Color(0xFFF8F7FF),
//                 ),
//                 foregroundColor: WidgetStateProperty.resolveWith(
//                   (s) => s.contains(WidgetState.selected)
//                       // AppColors.accent — #894DEF
//                       ? const Color(0xFF894DEF)
//                       // AppColors.hint — #767676
//                       : const Color(0xFF767676),
//                 ),
//                 side: WidgetStateProperty.all(
//                   // AppColors.border — #D4D4D4
//                   const BorderSide(color: Color(0xFFD4D4D4)),
//                 ),
//                 padding: WidgetStateProperty.all(
//                   const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 ),
//               ),
//               segments: const [
//                 ButtonSegment(
//                   value: CalendarFormat.month,
//                   label: Text(
//                     'Month',
//                     style: TextStyle(fontSize: 12),
//                     softWrap: false,
//                     maxLines: 1,
//                     overflow: TextOverflow.visible,
//                   ),
//                 ),
//                 ButtonSegment(
//                   value: CalendarFormat.week,
//                   label: Text(
//                     'Week',
//                     style: TextStyle(fontSize: 12),
//                     softWrap: false,
//                     maxLines: 1,
//                     overflow: TextOverflow.visible,
//                   ),
//                 ),
//               ],
//               selected: {_calendarFormat},
//               onSelectionChanged: (v) =>
//                   setState(() => _calendarFormat = v.first),
//               showSelectedIcon: false,
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Container(
//             // AppColors.surface — #F8F7FF
//             color: const Color(0xFFF8F7FF),
//             child: TableCalendar<Object>( // [Object → SessionEntity]
//               firstDay: DateTime.now().subtract(const Duration(days: 365)),
//               lastDay: DateTime.now().add(const Duration(days: 365)),
//               focusedDay: _focusedDay,
//               calendarFormat: _calendarFormat,
//               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//               eventLoader: (day) => _sessionsForDay(sessions, day),
//               onDaySelected: (selected, focused) => setState(() {
//                 _selectedDay = selected;
//                 _focusedDay = focused;
//               }),
//               onFormatChanged: (f) => setState(() => _calendarFormat = f),
//               // [also call ref.read(calendarWindowProvider.notifier).advanceToMonth(f)]
//               onPageChanged: (f) => setState(() => _focusedDay = f),
//               headerStyle: const HeaderStyle(
//                 formatButtonVisible: false,
//                 titleCentered: true,
//               ),
//               calendarStyle: CalendarStyle(
//                 selectedDecoration: const BoxDecoration(
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                   shape: BoxShape.circle,
//                 ),
//                 todayDecoration: BoxDecoration(
//                   // AppColors.secondary — #EDE9FE
//                   color: const Color(0xFFEDE9FE),
//                   shape: BoxShape.circle,
//                   // AppColors.accent — #894DEF
//                   border: Border.all(color: const Color(0xFF894DEF)),
//                 ),
//                 todayTextStyle: const TextStyle(
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                   fontWeight: FontWeight.w600,
//                 ),
//                 outsideDaysVisible: false,
//               ),
//               calendarBuilders: CalendarBuilders<Object>( // [Object → SessionEntity]
//                 defaultBuilder: (context, day, _) {
//                   final daySessions = _sessionsForDay(sessions, day);
//                   // [hasPersonal: session.memberUids.contains(currentUserId) || session.hostUid == currentUserId]
//                   // [old used: s.myStatus == JoinStatus.joined || s.myStatus == JoinStatus.host]
//                   final hasPersonal = daySessions.isNotEmpty; // [replace with membership check above]
//                   if (!hasPersonal) return null;
//                   return Container(
//                     margin: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(
//                       // AppColors.secondary — #EDE9FE
//                       color: Color(0xFFEDE9FE),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text(
//                         '${day.day}',
//                         style: const TextStyle(
//                           // AppColors.accent — #894DEF
//                           color: Color(0xFF894DEF),
//                           fontWeight: FontWeight.w600,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//                 markerBuilder: (context, day, events) {
//                   if (events.isEmpty) return const SizedBox.shrink();
//                   // [old: e.subject.color — no Subject enum in new stack (ADR 0003)]
//                   // [new: map session.status → color:
//                   //   'scheduled'/'active' → AppColors.accent #894DEF
//                   //   'ended'              → AppColors.hint   #767676
//                   //   take up to 3 unique status-colors; deduplicate with .toSet()]
//                   final colors = <Color>[]; // [placeholder — replace with status-based mapping]
//                   return Positioned(
//                     bottom: 4,
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: colors
//                           .map(
//                             (c) => Container(
//                               width: 6,
//                               height: 6,
//                               margin:
//                                   const EdgeInsets.symmetric(horizontal: 1),
//                               decoration: BoxDecoration(
//                                 color: c,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                           )
//                           .toList(),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//           // AppColors.border — #D4D4D4
//           const Divider(height: 1, color: Color(0xFFD4D4D4)),
//           Expanded(
//             child: _selectedDay == null
//                 ? const _NoDateSelected()
//                 : selected.isEmpty
//                     ? _NoSessionsDay(date: _selectedDay!)
//                     : _DaySessionsPanel(date: _selectedDay!, sessions: selected),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Inline day-session panel shown below the calendar when a day is selected.
// // Shows top 3 sessions; overflow triggers push to /calendar/day.
// class _DaySessionsPanel extends StatelessWidget {
//   final DateTime date;
//   final List<Object> sessions; // [List<SessionEntity>; already sorted by scheduledAt asc]

//   const _DaySessionsPanel({required this.date, required this.sessions});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     // [receive list already sorted by scheduledAt asc from use case; do not sort here]
//     final n = sessions.length;
//     final showOverflow = n > 3;

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(bottom: 8),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   // [DateFormat('MMMM d').format(date)]
//                   '📅 ${DateFormat('MMMM d').format(date)} · $n sessions',
//                   style: tt.bodyMedium,
//                 ),
//               ),
//               if (showOverflow)
//                 TextButton(
//                   style: TextButton.styleFrom(
//                     // AppColors.accent — #894DEF
//                     foregroundColor: const Color(0xFF894DEF),
//                     padding: EdgeInsets.zero,
//                     minimumSize: Size.zero,
//                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                   ),
//                   // [context.push('/calendar/day', extra: (date, sessions))]
//                   onPressed: () {},
//                   child: const Text('See all →'),
//                 ),
//             ],
//           ),
//         ),
//         // [top 3 SessionCards — lib/shared/widgets/session_card.dart
//         //  pass session: sessions[i], currentUserId, onTap → route per ADR 0003]
//         ...List.generate(
//           sessions.take(3).length,
//           (_) => const SizedBox.shrink(), // [replace with SessionCard]
//         ),
//         if (showOverflow)
//           GestureDetector(
//             // [context.push('/calendar/day', extra: (date, sessions))]
//             onTap: () {},
//             child: Container(
//               margin: const EdgeInsets.only(top: 4),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               decoration: BoxDecoration(
//                 // Color(0xFFF5F5F5) — hardcoded hex (no AppColors token)
//                 color: const Color(0xFFF5F5F5),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 '＋ ${n - 3} more sessions — see all',
//                 // Color(0xFF5186CD) — hardcoded hex (no AppColors token)
//                 style: tt.labelLarge?.copyWith(color: const Color(0xFF5186CD)),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }

// class _NoDateSelected extends StatelessWidget {
//   const _NoDateSelected();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.touch_app_outlined,
//             size: 52,
//             // AppColors.disabled — #DED8F7
//             color: Color(0xFFDED8F7),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Tap a day to see sessions',
//             // AppColors.hint — #767676
//             style: Theme.of(context)
//                 .textTheme
//                 .bodyMedium
//                 ?.copyWith(color: const Color(0xFF767676)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _NoSessionsDay extends StatelessWidget {
//   final DateTime date;
//   const _NoSessionsDay({required this.date});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.event_busy_outlined,
//             size: 52,
//             // AppColors.disabled — #DED8F7
//             color: Color(0xFFDED8F7),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             // [DateFormat('MMMM d').format(date)]
//             'No sessions on ${DateFormat('MMMM d').format(date)}',
//             // AppColors.hint — #767676
//             style: Theme.of(context)
//                 .textTheme
//                 .bodyMedium
//                 ?.copyWith(color: const Color(0xFF767676)),
//           ),
//         ],
//       ),
//     );
//   }
// }
