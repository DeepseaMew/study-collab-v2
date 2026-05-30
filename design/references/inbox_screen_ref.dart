// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// class MessagesScreen extends StatefulWidget {
//   const MessagesScreen({super.key});

//   @override
//   State<MessagesScreen> createState() => _MessagesScreenState();
// }

// class _MessagesScreenState extends State<MessagesScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final _searchCtrl = TextEditingController();
//   String _query = '';

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _tabController.addListener(() => setState(() {}));
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [state: unreadDmTotalProvider — int total unread DM count across all conversations]
//     // [state: unreadGroupTotalProvider — int total unread group chat count]
//     const dmUnread = 0; // [unreadDmTotalProvider]
//     const grpUnread = 0; // [unreadGroupTotalProvider]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         titleSpacing: 20,
//         title: const Text('Messages'),
//         actions: const [],
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(92),
//           child: Column(
//             children: [
//               // ── Search bar ────────────────────────────────────────────────
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
//                 child: TextField(
//                   controller: _searchCtrl,
//                   onChanged: (v) => setState(() => _query = v),
//                   decoration: const InputDecoration(
//                     hintText: 'Search conversations...',
//                     prefixIcon: Icon(Icons.search, size: 20),
//                     contentPadding: EdgeInsets.symmetric(vertical: 10),
//                   ),
//                 ),
//               ),
//               // ── Tab bar ───────────────────────────────────────────────────
//               TabBar(
//                 controller: _tabController,
//                 tabs: [
//                   Tab(
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Text('Individual'),
//                         if (dmUnread > 0) ...[
//                           const SizedBox(width: 6),
//                           _UnreadBadge(count: dmUnread),
//                         ],
//                       ],
//                     ),
//                   ),
//                   Tab(
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Text('Groups'),
//                         if (grpUnread > 0) ...[
//                           const SizedBox(width: 6),
//                           _UnreadBadge(count: grpUnread),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _IndividualTab(query: _query),
//           const _GroupsTab(),
//         ],
//       ),
//     );
//   }
// }

// // ── Unread badge ──────────────────────────────────────────────────────────────

// class _UnreadBadge extends StatelessWidget {
//   final int count;
//   const _UnreadBadge({required this.count});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         // AppColors.error — #CC0000
//         color: const Color(0xFFCC0000),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Text(
//         '$count',
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 10,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//     );
//   }
// }

// // ── Individual Tab ────────────────────────────────────────────────────────────

// class _IndividualTab extends StatelessWidget {
//   final String query;
//   const _IndividualTab({required this.query});

//   // [filter: returns conversations whose otherUserName contains query, case-insensitive]
//   List<dynamic> _filtered(List<dynamic> all) {
//     if (query.isEmpty) return all;
//     return all
//         .where(
//           (c) => c.otherUserName.toLowerCase().contains(query.toLowerCase()),
//         )
//         .toList();
//   }

//   // [time label: 'just now', '{N}m ago', '{N}h ago', '{N}d ago', 'MMM d']
//   String _timeAgo(DateTime dt) {
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 1) return 'just now';
//     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
//     if (diff.inHours < 24) return '${diff.inHours}h ago';
//     if (diff.inDays < 7) return '${diff.inDays}d ago';
//     return ''; // DateFormat('MMM d').format(dt)
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [state: userDmConversationsProvider — AsyncValue<List<DmConversation>>]
//     // [state: authStateProvider — myUid String]
//     // [display name resolution per convo:
//     //   1. c.otherUserName (denormalized)
//     //   2. friends list lookup by otherUid  ← [state: friendsProvider]
//     //   3. fallback: 'Unknown User'
//     //   never expose raw UID]

//     // asyncConvos.when(
//     //   loading: () => const Center(child: CircularProgressIndicator()),
//     //   error:   (e, _) => _EmptyState(icon: Icons.error_outline,
//     //                         title: 'Something went wrong',
//     //                         subtitle: 'Could not load conversations. Please try again.'),
//     //   data:    (convos) => filtered.isEmpty ? _EmptyState : ListView,
//     // )
//     return Column(
//       children: [
//         // empty state — no query:
//         // _EmptyState(
//         //   icon: Icons.chat_bubble_outline,
//         //   title: 'No conversations yet',
//         //   subtitle: "Start a chat from someone's profile page",
//         // )

//         // empty state — query with no results:
//         // _EmptyState(
//         //   icon: Icons.chat_bubble_outline,
//         //   title: 'No results found',
//         //   subtitle: 'Try a different name',
//         // )

//         // data state:
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(vertical: 4),
//             itemCount: 0, // [filtered.length]
//             separatorBuilder: (_, i) => const Divider(
//               height: 1,
//               indent: 76,
//               // AppColors.border — #D4D4D4
//               color: Color(0xFFD4D4D4),
//             ),
//             itemBuilder: (ctx, i) => const _DmTile(
//               // convo: filtered[i]
//               // displayLabel: resolved display name
//               // myUid: myUid
//               // timeAgo: c.lastMessageAt != null ? _timeAgo(c.lastMessageAt!) : ''
//               // onTap: markDmRead then context.push('/messages/dm/${c.id}')
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _DmTile extends StatelessWidget {
//   // final DmConversation convo;
//   // final String displayLabel;
//   // final String myUid;
//   // final String timeAgo;
//   // final VoidCallback onTap;

//   const _DmTile();

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     const hasUnread = false; // [convo.unreadCountForMe > 0]
//     const displayLabel = ''; // [resolved display name]
//     const initial = '?'; // [displayLabel[0].toUpperCase()]
//     const timeAgo = '';

//     return ListTile(
//       // onTap: onTap,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       leading: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           CircleAvatar(
//             radius: 26,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: const Color(0xFFEDE9FE),
//             child: const Text(
//               initial,
//               style: TextStyle(
//                 // AppColors.accent — #894DEF
//                 color: Color(0xFF894DEF),
//                 fontWeight: FontWeight.w600,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//           if (hasUnread)
//             Positioned(
//               right: -3,
//               top: -3,
//               child: Container(
//                 width: 20,
//                 height: 20,
//                 decoration: const BoxDecoration(
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Text(
//                     // '${convo.unreadCountForMe}'
//                     '0',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//       title: Row(
//         children: [
//           Expanded(
//             child: Text(
//               displayLabel,
//               style: tt.labelLarge?.copyWith(
//                 fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
//               ),
//             ),
//           ),
//           if (timeAgo.isNotEmpty)
//             Text(
//               timeAgo,
//               style: tt.labelSmall?.copyWith(
//                 // AppColors.accent — #894DEF  (unread)
//                 // AppColors.hint  — #767676   (read)
//                 color: hasUnread
//                     ? const Color(0xFF894DEF)
//                     : const Color(0xFF767676),
//               ),
//             ),
//         ],
//       ),
//       subtitle: Row(
//         children: [
//           Expanded(
//             child: Text(
//               // convo.lastMessageText ?? ''
//               '',
//               style: tt.bodyMedium?.copyWith(
//                 // AppColors.text — #1A1A2E  (unread)
//                 // AppColors.hint — #767676  (read)
//                 color: hasUnread
//                     ? const Color(0xFF1A1A2E)
//                     : const Color(0xFF767676),
//                 fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           if (hasUnread)
//             Padding(
//               padding: const EdgeInsets.only(left: 6),
//               child: Text(
//                 // '${convo.unreadCountForMe} DM${convo.unreadCountForMe > 1 ? 's' : ''}'
//                 '1 DM',
//                 style: const TextStyle(
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// // ── Groups Tab ────────────────────────────────────────────────────────────────

// class _GroupsTab extends StatelessWidget {
//   const _GroupsTab();

//   // [time label: 'just now', '{N}m ago', '{N}h ago', '{N}d ago', 'MMM d']
//   String _timeAgo(DateTime dt) {
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 1) return 'just now';
//     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
//     if (diff.inHours < 24) return '${diff.inHours}h ago';
//     if (diff.inDays < 7) return '${diff.inDays}d ago';
//     return ''; // DateFormat('MMM d').format(dt)
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [state: userGroupConversationsProvider — AsyncValue<List<GroupConversation>>]

//     // asyncGroups.when(
//     //   loading: () => const Center(child: CircularProgressIndicator()),
//     //   error:   (e, _) => _EmptyState(icon: Icons.error_outline,
//     //                         title: 'Something went wrong',
//     //                         subtitle: 'Could not load group chats. Please try again.'),
//     //   data:    (groups) => groups.isEmpty ? _EmptyState : ListView,
//     // )
//     return Column(
//       children: [
//         // empty state:
//         // _EmptyState(
//         //   icon: Icons.group_outlined,
//         //   title: 'No group chats yet',
//         //   subtitle: 'Join a session to access its group chat',
//         // )

//         // data state:
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(vertical: 4),
//             itemCount: 0, // [groups.length]
//             separatorBuilder: (_, i) => const Divider(
//               height: 1,
//               indent: 76,
//               // AppColors.border — #D4D4D4
//               color: Color(0xFFD4D4D4),
//             ),
//             itemBuilder: (ctx, i) => const _GroupTile(
//               // group: groups[i]
//               // timeAgo: g.lastMessageAt != null ? _timeAgo(g.lastMessageAt!) : ''
//               // onTap: () => context.push('/session/${g.sessionId}/chat')
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _GroupTile extends StatelessWidget {
//   // final GroupConversation group;
//   // final String timeAgo;
//   // final VoidCallback onTap;

//   const _GroupTile();

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     const hasUnread = false; // [group.unreadCountForMe > 0]
//     const initial = 'G'; // [group.sessionTitle[0].toUpperCase() or 'G']
//     const timeAgo = '';

//     return ListTile(
//       // onTap: onTap,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       leading: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           CircleAvatar(
//             radius: 26,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: const Color(0xFFEDE9FE),
//             child: const Text(
//               initial,
//               style: TextStyle(
//                 // AppColors.accent — #894DEF
//                 color: Color(0xFF894DEF),
//                 fontWeight: FontWeight.w600,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//           if (hasUnread)
//             Positioned(
//               right: -3,
//               top: -3,
//               child: Container(
//                 width: 20,
//                 height: 20,
//                 decoration: const BoxDecoration(
//                   // AppColors.accent — #894DEF
//                   color: Color(0xFF894DEF),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Text(
//                     // '${group.unreadCountForMe}'
//                     '0',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//       title: Row(
//         children: [
//           Expanded(
//             child: Text(
//               // group.sessionTitle
//               '',
//               style: tt.labelLarge?.copyWith(
//                 fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           if (timeAgo.isNotEmpty)
//             Text(
//               timeAgo,
//               style: tt.labelSmall?.copyWith(
//                 // AppColors.accent — #894DEF  (unread)
//                 // AppColors.hint  — #767676   (read)
//                 color: hasUnread
//                     ? const Color(0xFF894DEF)
//                     : const Color(0xFF767676),
//               ),
//             ),
//         ],
//       ),
//       subtitle: Row(
//         children: [
//           Expanded(
//             child: Text(
//               // group.lastMessageText ?? 'No messages yet'
//               'No messages yet',
//               style: tt.bodyMedium?.copyWith(
//                 // AppColors.text — #1A1A2E  (unread)
//                 // AppColors.hint — #767676  (read)
//                 color: hasUnread
//                     ? const Color(0xFF1A1A2E)
//                     : const Color(0xFF767676),
//                 fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const SizedBox(width: 6),
//           // [subject chip — group.sessionSubject.color (dynamic, not from AppColors)
//           //                  at 15% opacity background; text is group.sessionSubject.displayName]
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             decoration: BoxDecoration(
//               // [group.sessionSubject.color at 15% opacity — dynamic, resolve at runtime]
//               color: Colors.blue.withValues(alpha: 0.15), // placeholder
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Text(
//               // group.sessionSubject.displayName
//               '',
//               style: tt.labelSmall?.copyWith(
//                 // [group.sessionSubject.color — dynamic]
//                 color: Colors.blue, // placeholder
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Empty state ───────────────────────────────────────────────────────────────

// class _EmptyState extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;

//   const _EmptyState({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               // AppColors.secondary — #EDE9FE
//               color: const Color(0xFFEDE9FE),
//               borderRadius: BorderRadius.circular(40),
//             ),
//             child: Icon(
//               icon,
//               size: 36,
//               // AppColors.accent — #894DEF
//               color: const Color(0xFF894DEF),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(title, style: tt.displaySmall),
//           const SizedBox(height: 6),
//           Text(
//             subtitle,
//             style: tt.bodyMedium?.copyWith(
//               // AppColors.hint — #767676
//               color: const Color(0xFF767676),
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }
