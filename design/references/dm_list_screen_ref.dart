// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// class DmListScreen extends StatefulWidget {
//   const DmListScreen({super.key});

//   @override
//   State<DmListScreen> createState() => _DmListScreenState();
// }

// class _DmListScreenState extends State<DmListScreen> {
//   final _searchCtrl = TextEditingController();
//   String _query = '';

//   @override
//   void dispose() {
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   // [filter: returns conversations whose otherUserName contains _query, case-insensitive]
//   List<dynamic> _filtered(List<dynamic> all) {
//     if (_query.isEmpty) return all;
//     return all
//         .where(
//           (c) => c.otherUserName.toLowerCase().contains(_query.toLowerCase()),
//         )
//         .toList();
//   }

//   // [action: markDmRead(conversationId: convo.id, userId: myUid) fire-and-forget,
//   //          then context.push('/messages/dm/${convo.id}')]
//   Future<void> _onTap(dynamic convo, String myUid) async {}

//   @override
//   Widget build(BuildContext context) {
//     // [state: userDmConversationsProvider — AsyncValue<List<DmConversation>>]
//     // [state: authStateProvider — myUid String]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(title: const Text('Messages')),
//       body: Column(
//         children: [
//           // ── Search bar ──────────────────────────────────────────────────────
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//             child: TextField(
//               controller: _searchCtrl,
//               onChanged: (v) => setState(() => _query = v),
//               decoration: const InputDecoration(
//                 hintText: 'Search conversations...',
//                 prefixIcon: Icon(Icons.search, size: 20),
//                 contentPadding: EdgeInsets.symmetric(vertical: 10),
//               ),
//             ),
//           ),
//           // AppColors.border — #D4D4D4
//           const Divider(height: 1, color: Color(0xFFD4D4D4)),

//           // ── Conversation list ───────────────────────────────────────────────
//           // asyncConvos.when(
//           //   loading: () => const Center(child: CircularProgressIndicator()),
//           //   error:   (e, _) => [error text — see below],
//           //   data:    (convos) => filtered.isEmpty ? _EmptyState : ListView,
//           // )
//           Expanded(
//             child: Column(
//               children: [
//                 // error state ─────────────────────────────────────────────────
//                 // Center(
//                 //   child: Padding(
//                 //     padding: const EdgeInsets.symmetric(horizontal: 24),
//                 //     child: Text(
//                 //       'Could not load conversations. Please try again.',
//                 //       style: tt.bodyMedium?.copyWith(
//                 //         // AppColors.hint — #767676
//                 //         color: const Color(0xFF767676),
//                 //       ),
//                 //       textAlign: TextAlign.center,
//                 //     ),
//                 //   ),
//                 // ),

//                 // data state ─────────────────────────────────────────────────
//                 // if filtered.isEmpty → _EmptyState(hasQuery: _query.isNotEmpty)
//                 // else:
//                 Expanded(
//                   child: ListView.separated(
//                     itemCount: 0, // [filtered.length]
//                     separatorBuilder: (_, i) => const Divider(
//                       height: 1,
//                       indent: 76,
//                       // AppColors.border — #D4D4D4
//                       color: Color(0xFFD4D4D4),
//                     ),
//                     itemBuilder: (ctx, i) => const _ConvoTile(
//                       // convo: filtered[i]
//                       // myUid: myUid
//                       // onTap: () => _onTap(filtered[i], myUid)
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Conversation tile ─────────────────────────────────────────────────────────

// class _ConvoTile extends StatelessWidget {
//   // final DmConversation convo;
//   // final String myUid;
//   // final VoidCallback onTap;

//   const _ConvoTile();

//   // [display name resolution order:
//   //   1. convo.otherUserName (denormalized on Firestore doc)
//   //   2. friends list lookup by otherUid  ← [state: friendsProvider]
//   //   3. fallback: 'Unknown User'
//   //   initial letter comes from resolved name, never raw UID]

//   // [time label: 'h:mm a' if today, 'Yesterday', 'MMM d' otherwise]

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     const hasUnread = false; // [convo.unreadCountForMe > 0]
//     const displayLabel = ''; // [resolved display name — see resolution order above]
//     const initial = '?'; // [displayLabel[0].toUpperCase()]

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
//             child: Text(
//               initial,
//               style: const TextStyle(
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
//       title: Text(
//         displayLabel,
//         style: tt.labelLarge?.copyWith(
//           fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
//         ),
//       ),
//       subtitle: Text(
//         // convo.lastMessageText ?? ''
//         '',
//         style: tt.bodyMedium?.copyWith(
//           // AppColors.text — #1A1A2E  (unread)
//           // AppColors.hint — #767676  (read)
//           color: hasUnread ? const Color(0xFF1A1A2E) : const Color(0xFF767676),
//           fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
//         ),
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       ),
//       // trailing: convo.lastMessageAt != null
//       //     ? Text(_timeLabel(convo.lastMessageAt!), style: tt.labelSmall)
//       //     : null,
//     );
//   }
// }

// // ── Empty state ───────────────────────────────────────────────────────────────

// class _EmptyState extends StatelessWidget {
//   final bool hasQuery;
//   const _EmptyState({required this.hasQuery});

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
//             child: const Icon(
//               Icons.chat_bubble_outline,
//               size: 36,
//               // AppColors.accent — #894DEF
//               color: Color(0xFF894DEF),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             hasQuery ? 'No results found' : 'No messages yet',
//             style: tt.displaySmall,
//           ),
//           const SizedBox(height: 6),
//           Text(
//             hasQuery
//                 ? 'Try a different name'
//                 : "Start a conversation from someone's profile",
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
