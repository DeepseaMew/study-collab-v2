// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// // Field note: old Session.startTime → SessionEntity.scheduledAt (.toDate() for DateTime).
// // Use ListView.builder with itemCount per CLAUDE.md (original used unbounded ListView).
// // Sorting (by scheduledAt asc) must happen in the use case or repository, not in build().

// class DaySessionsScreen extends StatelessWidget {
//   // [receives: day (DateTime) and sessions (List<SessionEntity>) via GoRouter extra;
//   //  list is already sorted by scheduledAt asc before being passed]
//   final DateTime day;
//   final List<Object> sessions; // [List<SessionEntity>]

//   const DaySessionsScreen({
//     super.key,
//     required this.day,
//     required this.sessions,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     final n = sessions.length;

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: true,
//         toolbarHeight: 64,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Calendar',
//               // AppColors.hint — #767676
//               style: tt.labelSmall?.copyWith(color: const Color(0xFF767676)),
//             ),
//             Text(
//               // [DateFormat('MMMM d').format(day) — use package:intl/intl.dart]
//               '${DateFormat('MMMM d').format(day)} — All Sessions',
//               style: tt.titleLarge,
//             ),
//           ],
//         ),
//       ),
//       body: ListView.builder(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
//         itemCount: n + 1, // +1 for the count label header
//         itemBuilder: (context, index) {
//           if (index == 0) {
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 12),
//               child: Text(
//                 '$n sessions · sorted by start time',
//                 // AppColors.hint — #767676
//                 style: tt.labelSmall?.copyWith(color: const Color(0xFF767676)),
//               ),
//             );
//           }
//           // [SessionCard — lib/shared/widgets/session_card.dart
//           //  pass session: sessions[index - 1], currentUserId, onTap → route per ADR 0003
//           //  (host-owned → /my-sessions/session/:id/host; joined → /my-sessions/session/:id/member)]
//           return const SizedBox.shrink(); // placeholder
//         },
//       ),
//     );
//   }
// }
