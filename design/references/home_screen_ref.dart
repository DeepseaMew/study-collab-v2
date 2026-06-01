// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   // [action] Pull-to-refresh — call watchPublicSessions use case to reload feed
//   Future<void> _onRefresh() async {
//     // [trigger real session stream refresh here]
//     await Future.delayed(const Duration(milliseconds: 800));
//     if (mounted) setState(() {});
//   }

//   String _greeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return 'Good morning';
//     if (hour < 17) return 'Good afternoon';
//     return 'Good evening';
//   }

//   // [action] Open search bottom sheet
//   void _openSearch() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const Placeholder(), // [SearchBottomSheet widget]
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;

//     // [state] Watch auth state → derive firstName and avatarUrl for AppBar
//     // final authState = ref.watch(authStateProvider);
//     const firstName = 'Student'; // [replace with user.displayName.split(' ').first]
//     const avatarUrl = ''; // [replace with user.photoUrl ?? '']

//     // [state] Watch public sessions stream filtered to notJoined status
//     // final asyncSessions = ref.watch(publicSessionsProvider);
//     // final discoverSessions = allSessions.where((s) => s.myStatus == JoinStatus.notJoined).toList();
//     final discoverSessions = <dynamic>[]; // [replace with real session list]

//     // [state] Watch unread notification count for badge
//     // final unreadCount = ref.watch(unreadNotificationCountProvider);
//     const unreadCount = 0; // [replace with real count]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         titleSpacing: 20,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('${_greeting()}, $firstName 👋', style: tt.displaySmall),
//             Text(
//               'Find your next study session',
//               // AppColors.hint — #767676
//               style: tt.bodyMedium?.copyWith(color: const Color(0xFF767676)),
//             ),
//           ],
//         ),
//         actions: [
//           // Profile avatar — taps navigate to /profile
//           GestureDetector(
//             onTap: () => Navigator.pushNamed(context, '/profile'),
//             child: Padding(
//               padding: const EdgeInsets.only(right: 4),
//               child: CircleAvatar(
//                 radius: 17,
//                 // AppColors.secondary — #EDE9FE
//                 backgroundColor: const Color(0xFFEDE9FE),
//                 backgroundImage:
//                     avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
//                 child: avatarUrl.isEmpty
//                     ? Text(
//                         firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
//                         style: const TextStyle(
//                           // AppColors.accent — #894DEF
//                           color: Color(0xFF894DEF),
//                           fontWeight: FontWeight.w600,
//                           fontSize: 14,
//                         ),
//                       )
//                     : null,
//               ),
//             ),
//           ),
//           // Notification bell — show numeric badge when unreadCount > 0
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             // [Badge — show numeric dot when unreadCount > 0]
//             // badges.Badge(
//             //   badgeContent: Text('$unreadCount', style: TextStyle(color: Colors.white, fontSize: 10)),
//             //   showBadge: unreadCount > 0,
//             //   position: badges.BadgePosition.topEnd(top: -4, end: -4),
//             //   badgeStyle: badges.BadgeStyle(
//             //     badgeColor: Color(0xFF894DEF),  // AppColors.accent — #894DEF
//             //     padding: EdgeInsets.all(4),
//             //   ),
//             //   child: IconButton(icon: Icon(Icons.notifications_outlined), onPressed: ...),
//             // )
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.notifications_outlined),
//                   onPressed: () => Navigator.pushNamed(context, '/notifications'),
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     top: 8,
//                     right: 8,
//                     child: Container(
//                       width: 16,
//                       height: 16,
//                       decoration: const BoxDecoration(
//                         // AppColors.accent — #894DEF
//                         color: Color(0xFF894DEF),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Center(
//                         child: Text(
//                           '$unreadCount',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Fake search bar — taps open SearchBottomSheet
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//             child: GestureDetector(
//               onTap: _openSearch,
//               child: Container(
//                 height: 48,
//                 decoration: BoxDecoration(
//                   // AppColors.surface — #F8F7FF
//                   color: const Color(0xFFF8F7FF),
//                   borderRadius: BorderRadius.circular(8),
//                   // AppColors.border — #D4D4D4
//                   border: Border.all(color: const Color(0xFFD4D4D4)),
//                 ),
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 child: Row(
//                   children: [
//                     const Icon(
//                       Icons.search,
//                       // AppColors.hint — #767676
//                       color: Color(0xFF767676),
//                       size: 20,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Search sessions, #hashtags, @hosts...',
//                       style: tt.bodyMedium?.copyWith(
//                         // AppColors.hint — #767676
//                         color: const Color(0xFF767676),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: RefreshIndicator(
//               onRefresh: _onRefresh,
//               // AppColors.accent — #894DEF
//               color: const Color(0xFF894DEF),
//               child: discoverSessions.isEmpty
//                   ? const _EmptyState()
//                   : ListView.builder(
//                       padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
//                       itemCount: discoverSessions.length,
//                       itemBuilder: (context, index) =>
//                           // [SessionCard widget — pass session: discoverSessions[index]]
//                           const Placeholder(),
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Empty state ──────────────────────────────────────────────────────────────

// class _EmptyState extends StatelessWidget {
//   const _EmptyState();

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return ListView(
//       children: [
//         SizedBox(
//           height: MediaQuery.of(context).size.height * 0.55,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   // AppColors.secondary — #EDE9FE
//                   color: const Color(0xFFEDE9FE),
//                   borderRadius: BorderRadius.circular(50),
//                 ),
//                 child: const Icon(
//                   Icons.explore_outlined,
//                   size: 48,
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text('All caught up!', style: tt.displaySmall),
//               const SizedBox(height: 8),
//               Text(
//                 "You've joined all available sessions.\nCreate one or check back later!",
//                 style: tt.bodyMedium?.copyWith(
//                   // AppColors.hint — #767676
//                   color: const Color(0xFF767676),
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
