// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // Schema notes:
// //   Route: /session/:id/members  (no ADR 0003 equivalent defined yet — confirm with architect)
// //   Participant model → use domain entity; member fields below mapped to ADR 0001 users schema:
// //     m.username      → member.displayName  (ADR 0001: users/{uid}.displayName)
// //     m.profilePhotoUrl → member.photoUrl   (ADR 0001: users/{uid}.photoUrl)
// //     m.isHost        → session.hostUid == member.uid  (derive from session, not participant flag)
// //   NetworkImage     → CachedNetworkImageProvider  (CLAUDE.md convention)

// // ── Members list screen ────────────────────────────────────────────────────────

// class MembersListScreen extends StatelessWidget {
//   final String id;
//   const MembersListScreen({super.key, required this.id});

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionMembersProvider(id) → AsyncValue<List<UserEntity>>]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         // AppColors.background — #FFFFFF
//         backgroundColor: AppColors.background,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//           ),
//           onPressed: () {}, // [context.pop()]
//         ),
//         title: const Text(
//           'Members',
//           style: TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: // membersAsync.when(
//           //   loading: () =>
//           const Center(child: CircularProgressIndicator()),
//       //   error: (e, _) => Center(
//       //     child: Text(
//       //       e.toString(),
//       //       style: const TextStyle(color: AppColors.hint — #767676),
//       //     ),
//       //   ),
//       //   data: (members) => _MembersList(members: members, hostUid: hostUid),
//       // )
//     );
//   }
// }

// // ── Members list ───────────────────────────────────────────────────────────────

// class _MembersList extends StatelessWidget {
//   // [members: List<UserEntity>, hostUid: String]
//   const _MembersList({required this.members, required this.hostUid});

//   @override
//   Widget build(BuildContext context) {
//     if (members.isEmpty) {
//       return const Center(
//         child: Text(
//           'No members yet.',
//           // AppColors.hint — #767676
//           style: TextStyle(color: AppColors.hint),
//         ),
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//       itemCount: members.length,
//       separatorBuilder: (_, __) => const Divider(
//         // AppColors.border — #D4D4D4
//         color: AppColors.border,
//       ),
//       itemBuilder: (_, i) {
//         final m = members[i];
//         final isHost = m.uid == hostUid; // [derive host status from hostUid, not a participant flag]
//         final initial =
//             m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?';

//         return ListTile(
//           contentPadding: EdgeInsets.zero,
//           leading: CircleAvatar(
//             radius: 20,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: AppColors.secondary,
//             // [CachedNetworkImageProvider — use cached_network_image when m.photoUrl != null && isNotEmpty]
//             backgroundImage: m.photoUrl != null && m.photoUrl!.isNotEmpty
//                 ? null // replace null with CachedNetworkImageProvider(m.photoUrl!)
//                 : null,
//             child: m.photoUrl == null || m.photoUrl!.isEmpty
//                 ? Text(
//                     initial,
//                     style: const TextStyle(
//                       // AppColors.accent — #894DEF
//                       color: AppColors.accent,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   )
//                 : null,
//           ),
//           title: Text(
//             m.displayName,
//             style: const TextStyle(
//               // AppColors.text — #1A1A2E
//               color: AppColors.text,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           subtitle: Text(
//             isHost ? 'Host' : 'Member',
//             // AppColors.hint — #767676
//             style: const TextStyle(color: AppColors.hint, fontSize: 12),
//           ),
//         );
//       },
//     );
//   }
// }
