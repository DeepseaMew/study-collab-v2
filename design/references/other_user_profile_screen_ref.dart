// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// class OtherUserProfileScreen extends StatelessWidget {
//   final String userId;
//   const OtherUserProfileScreen({super.key, required this.userId});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;

//     // [state] Watch other user profile stream by userId
//     // final userAsync = ref.watch(otherUserProvider(userId));

//     // [state] Watch current user to compare IDs for action row visibility
//     // final currentUserAsync = ref.watch(currentUserProvider);

//     // Replace with real loading/error/data handling from provider:
//     // return userAsync.when(
//     //   loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
//     //   error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Failed to load profile: $e'))),
//     //   data: (user) { ... },
//     // );

//     // Stub values for layout reference:
//     const username = 'Other User';
//     const email = 'user@mail.kmutt.ac.th';
//     const bio = '';
//     const faculty = 'Engineering';
//     const studentYear = 2;
//     const academicLevelDisplay = 'Undergraduate';
//     const sessionsCount = 0;
//     const friendsCount = 0;
//     const profilePhotoUrl = '';
//     final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(title: Text(username)),
//       body: ListView(
//         padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
//         children: [
//           // Avatar + name + email
//           Center(
//             child: Column(
//               children: [
//                 CircleAvatar(
//                   radius: 40,
//                   // AppColors.accent — #894DEF at 15% opacity
//                   backgroundColor: const Color(0xFF894DEF).withValues(alpha: 0.15),
//                   backgroundImage: profilePhotoUrl.isNotEmpty
//                       // [cached network image from profilePhotoUrl]
//                       ? NetworkImage(profilePhotoUrl)
//                       : null,
//                   child: profilePhotoUrl.isEmpty
//                       ? Text(
//                           initial,
//                           style: const TextStyle(
//                             fontSize: 28,
//                             fontWeight: FontWeight.w700,
//                             // AppColors.accent — #894DEF
//                             color: Color(0xFF894DEF),
//                           ),
//                         )
//                       : null,
//                 ),
//                 const SizedBox(height: 12),
//                 Text(username, style: tt.displayMedium),
//                 const SizedBox(height: 2),
//                 Text(
//                   email,
//                   // AppColors.hint — #767676
//                   style: tt.bodyMedium?.copyWith(color: const Color(0xFF767676)),
//                 ),
//                 if (bio.isNotEmpty) ...[
//                   const SizedBox(height: 6),
//                   Text(
//                     bio,
//                     style: tt.bodyMedium?.copyWith(
//                       // AppColors.hint — #767676
//                       color: const Color(0xFF767676),
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//                 if (faculty.isNotEmpty) ...[
//                   const SizedBox(height: 6),
//                   Text(
//                     '$faculty · Year $studentYear · $academicLevelDisplay',
//                     style: tt.labelLarge?.copyWith(
//                       // AppColors.hint — #767676
//                       color: const Color(0xFF767676),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),
//           // Stats row — Sessions / Friends / Rating
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//             decoration: BoxDecoration(
//               // AppColors.surface — #F8F7FF
//               color: const Color(0xFFF8F7FF),
//               borderRadius: BorderRadius.circular(12),
//               // AppColors.border — #D4D4D4
//               border: Border.all(color: const Color(0xFFD4D4D4)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _StatItem(
//                   label: 'Sessions',
//                   value: sessionsCount.toString(),
//                 ),
//                 // AppColors.border — #D4D4D4
//                 Container(width: 1, height: 36, color: const Color(0xFFD4D4D4)),
//                 _StatItem(
//                   label: 'Friends',
//                   value: friendsCount.toString(),
//                 ),
//                 // AppColors.border — #D4D4D4
//                 Container(width: 1, height: 36, color: const Color(0xFFD4D4D4)),
//                 _RatingStatItem(sessionCount: sessionsCount),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           // [action] Friend + message actions — only show if currentUser.uid != user.uid
//           // if (currentUser != null && currentUser.id != user.id)
//           const _FriendActionsPlaceholder(),
//           const SizedBox(height: 28),
//           Text(
//             "Sessions by ${username.split(' ').first}",
//             style: tt.titleLarge,
//           ),
//           const SizedBox(height: 12),
//           const _NoPublicSessions(),
//         ],
//       ),
//     );
//   }
// }

// // ── Friend / message action row ───────────────────────────────────────────────

// class _FriendActionsPlaceholder extends StatelessWidget {
//   const _FriendActionsPlaceholder();

//   @override
//   Widget build(BuildContext context) {
//     // [state] Watch friendship status between currentUser and otherUser
//     // final statusAsync = ref.watch(friendshipStatusProvider((currentUserId: ..., otherUserId: ...)));

//     // Renders differently per FriendshipStatus:
//     //   self          → SizedBox.shrink()
//     //   friends       → OutlinedButton.icon(Icons.people, 'Friends') + unfriend confirm dialog
//     //   requestSent   → OutlinedButton.icon(Icons.hourglass_empty_outlined, 'Request Sent')
//     //                    [action] onTap → withdrawRequest use case
//     //   requestReceived → ElevatedButton.icon(Icons.check, 'Accept Request')
//     //                    [action] onTap → acceptRequest use case
//     //   notFriends    → OutlinedButton.icon(Icons.person_add_outlined, 'Add Friend')
//     //                    [action] onTap → sendFriendRequest use case

//     return Row(
//       children: [
//         Expanded(
//           child: OutlinedButton.icon(
//             onPressed: null,
//             icon: const Icon(Icons.person_add_outlined, size: 18),
//             label: const Text('Add Friend'),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: ElevatedButton.icon(
//             // [action] Enabled only when friendship status == friends
//             // [action] onTap → getOrCreateDm use case → navigate to /messages/dm/{dmId}
//             onPressed: null,
//             icon: const Icon(Icons.chat_bubble_outline, size: 18),
//             label: const Text('Message'),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Unfriend confirmation dialog ──────────────────────────────────────────────
// // [action] Show before calling unfriend use case
// // AlertDialog(
// //   title: Text('Remove friend?'),
// //   content: Text('${otherUser.displayName} will no longer be able to message you.'),
// //   actions: [
// //     TextButton('Cancel'),
// //     TextButton('Remove'),
// //   ],
// // )

// // ── Subwidgets ────────────────────────────────────────────────────────────────

// class _StatItem extends StatelessWidget {
//   final String label;
//   final String value;
//   const _StatItem({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return Column(
//       children: [
//         Text(
//           value,
//           // AppColors.accent — #894DEF
//           style: tt.displayMedium?.copyWith(color: const Color(0xFF894DEF)),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           // AppColors.hint — #767676
//           style: tt.bodyMedium?.copyWith(color: const Color(0xFF767676)),
//         ),
//       ],
//     );
//   }
// }

// class _RatingStatItem extends StatelessWidget {
//   final int sessionCount;
//   const _RatingStatItem({required this.sessionCount});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(
//               Icons.thumb_up_rounded,
//               size: 18,
//               // AppColors.accent — #894DEF
//               color: Color(0xFF894DEF),
//             ),
//             const SizedBox(width: 4),
//             Text(
//               'N/A',
//               // AppColors.accent — #894DEF
//               style: tt.displayMedium?.copyWith(color: const Color(0xFF894DEF)),
//             ),
//           ],
//         ),
//         const SizedBox(height: 2),
//         Text(
//           'from $sessionCount sessions',
//           // AppColors.hint — #767676
//           style: tt.bodyMedium?.copyWith(color: const Color(0xFF767676)),
//         ),
//       ],
//     );
//   }
// }

// class _NoPublicSessions extends StatelessWidget {
//   const _NoPublicSessions();

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 32),
//         child: Column(
//           children: [
//             const Icon(
//               Icons.event_busy_outlined,
//               size: 48,
//               // AppColors.disabled — #DED8F7
//               color: Color(0xFFDED8F7),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'No public sessions',
//               // AppColors.hint — #767676
//               style: tt.bodyMedium?.copyWith(color: const Color(0xFF767676)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
