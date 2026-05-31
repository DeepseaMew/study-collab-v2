// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// // NOTE: Session/group chat is out of scope for ADR 0011 (DM only).
// // This reference documents the existing design for future group-chat ADR work.

// class SessionChatScreen extends StatefulWidget {
//   final String sessionId;

//   const SessionChatScreen({super.key, required this.sessionId});

//   @override
//   State<SessionChatScreen> createState() => _SessionChatScreenState();
// }

// class _SessionChatScreenState extends State<SessionChatScreen> {
//   final _inputCtrl = TextEditingController();
//   final _scrollCtrl = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     // On first frame: [action: markSessionChatRead(sessionId, myUid)] then _jumpToBottom()
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _jumpToBottom();
//     });
//   }

//   @override
//   void dispose() {
//     _inputCtrl.dispose();
//     _scrollCtrl.dispose();
//     super.dispose();
//   }

//   // [action: chatRepository.markSessionChatRead(sessionId, uid)
//   //          fire-and-forget; silently ignore failures]
//   Future<void> _markRead() async {}

//   void _jumpToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollCtrl.hasClients) {
//         _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
//       }
//     });
//   }

//   // [validation: text.trim().isEmpty → no-op]
//   // [state: currentUserProvider — needed for senderId, senderName, senderPhotoUrl]
//   // [action: chatRepository.sendSessionMessage(sessionId, senderId, senderName, senderPhotoUrl, text)
//   //          on success: _jumpToBottom()
//   //          on error: SnackBar 'Failed to send message. Please try again.']
//   Future<void> _send() async {
//     final text = _inputCtrl.text.trim();
//     if (text.isEmpty) return;
//     _inputCtrl.clear();
//   }

//   // [builds items list: interleaves DateTime sentinels between messages on different calendar days]
//   List<dynamic> _buildItems(List<dynamic> msgs) {
//     final items = <dynamic>[];
//     DateTime? lastDate;
//     for (final m in msgs) {
//       final d = DateUtils.dateOnly(m.sentAt as DateTime);
//       if (lastDate == null || d != lastDate) {
//         items.add(d);
//         lastDate = d;
//       }
//       items.add(m);
//     }
//     return items;
//   }

//   // [date label: 'Today', 'Yesterday', 'MMMM d, y']
//   String _dateLabel(DateTime d) {
//     final today = DateUtils.dateOnly(DateTime.now());
//     if (d == today) return 'Today';
//     if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
//     return d.toString(); // DateFormat('MMMM d, y').format(d)
//   }

//   // [title: resolved from userGroupConversationsProvider — find group where sessionId matches
//   //         falls back to 'Group Chat' if not yet loaded]
//   String _resolveTitle() {
//     return 'Group Chat'; // [resolved from userGroupConversationsProvider]
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [state: sessionMessagesProvider(sessionId) — AsyncValue<List<ChatMessage>>]
//     // [state: userGroupConversationsProvider — used to resolve title]
//     // [state: authStateProvider — myUid String]

//     final title = _resolveTitle();

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
//           onPressed: () {}, // context.pop()
//         ),
//         title: Text(title),
//       ),
//       body: Column(
//         children: [
//           // ── Message list ──────────────────────────────────────────────────
//           // asyncMessages.when(
//           //   loading: () => const Center(child: CircularProgressIndicator()),
//           //   error:   (e, _) => [error text — see below],
//           //   data:    (messages) => messages.isEmpty ? _EmptyGroupChat : ListView,
//           // )
//           Expanded(
//             child: Column(
//               children: [
//                 // error state ───────────────────────────────────────────────
//                 // Center(
//                 //   child: Padding(
//                 //     padding: const EdgeInsets.symmetric(horizontal: 24),
//                 //     child: Text(
//                 //       'Could not load messages. Please try again.',
//                 //       style: tt.bodyMedium?.copyWith(
//                 //         // AppColors.hint — #767676
//                 //         color: const Color(0xFF767676),
//                 //       ),
//                 //       textAlign: TextAlign.center,
//                 //     ),
//                 //   ),
//                 // ),

//                 // data: messages.isEmpty → const _EmptyGroupChat()
//                 // data: messages.isNotEmpty →
//                 Expanded(
//                   child: ListView.builder(
//                     controller: _scrollCtrl,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 12,
//                     ),
//                     itemCount: 0, // [items.length — after _buildItems interleaves date sentinels]
//                     itemBuilder: (ctx, i) {
//                       // if item is DateTime → _DateSeparator(label: _dateLabel(item))
//                       // else → _GroupChatBubble(message: msg, isMe: msg.senderId == myUid)
//                       return const SizedBox.shrink();
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Input bar ─────────────────────────────────────────────────────
//           _InputBar(controller: _inputCtrl, onSend: _send),
//         ],
//       ),
//     );
//   }
// }

// // ── Empty state ───────────────────────────────────────────────────────────────

// class _EmptyGroupChat extends StatelessWidget {
//   const _EmptyGroupChat();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.group_outlined,
//             size: 48,
//             // AppColors.disabled — #DED8F7
//             color: Color(0xFFDED8F7),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'No messages yet',
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//               // AppColors.hint — #767676
//               color: const Color(0xFF767676),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             'Be the first to say hello!',
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//               // AppColors.hint — #767676
//               color: const Color(0xFF767676),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Date separator ────────────────────────────────────────────────────────────

// class _DateSeparator extends StatelessWidget {
//   final String label;
//   const _DateSeparator({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 16),
//       child: Row(
//         children: [
//           // AppColors.border — #D4D4D4
//           const Expanded(child: Divider(color: Color(0xFFD4D4D4))),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             child: Text(
//               label,
//               style: Theme.of(context).textTheme.labelSmall?.copyWith(
//                 // AppColors.hint — #767676
//                 color: const Color(0xFF767676),
//               ),
//             ),
//           ),
//           // AppColors.border — #D4D4D4
//           const Expanded(child: Divider(color: Color(0xFFD4D4D4))),
//         ],
//       ),
//     );
//   }
// }

// // ── Group chat bubble ─────────────────────────────────────────────────────────
// // Own messages: right-aligned, accent background, no sender name.
// // Others: left-aligned, secondary background, sender name shown above bubble.

// class _GroupChatBubble extends StatelessWidget {
//   // final ChatMessage message;
//   final bool isMe;

//   const _GroupChatBubble({required this.isMe});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     // final initial = message.senderName[0].toUpperCase();
//     // final timeStr = DateFormat('h:mm a').format(message.sentAt);

//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         mainAxisAlignment:
//             isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
//         children: [
//           if (!isMe) ...[
//             // [avatar — tappable, navigates to '/user/${message.senderId}']
//             GestureDetector(
//               // onTap: () => context.push('/user/${message.senderId}'),
//               child: CircleAvatar(
//                 radius: 16,
//                 // AppColors.secondary — #EDE9FE
//                 backgroundColor: const Color(0xFFEDE9FE),
//                 // [cached network image from message.senderPhotoUrl if non-empty]
//                 // [fallback: initial letter Text widget]
//                 child: const Text(
//                   '?', // [initial]
//                   style: TextStyle(
//                     // AppColors.accent — #894DEF
//                     color: Color(0xFF894DEF),
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Flexible(
//             child: Column(
//               crossAxisAlignment:
//                   isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//               children: [
//                 // sender name — shown only for others (group context)
//                 if (!isMe)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 4, bottom: 2),
//                     child: Text(
//                       '', // [message.senderName]
//                       style: tt.labelSmall?.copyWith(
//                         // AppColors.hint — #767676
//                         color: const Color(0xFF767676),
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     // isMe: AppColors.accent — #894DEF
//                     // other: AppColors.secondary — #EDE9FE
//                     color: isMe
//                         ? const Color(0xFF894DEF)
//                         : const Color(0xFFEDE9FE),
//                     borderRadius: BorderRadius.only(
//                       topLeft: const Radius.circular(16),
//                       topRight: const Radius.circular(16),
//                       bottomLeft: Radius.circular(isMe ? 16 : 4),
//                       bottomRight: Radius.circular(isMe ? 4 : 16),
//                     ),
//                   ),
//                   child: Text(
//                     '', // [message.text]
//                     style: tt.bodyMedium?.copyWith(
//                       // isMe: white  /  other: AppColors.text — #1A1A2E
//                       color: isMe
//                           ? Colors.white
//                           : const Color(0xFF1A1A2E),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: Text(
//                     '', // [timeStr — DateFormat('h:mm a').format(message.sentAt)]
//                     style: tt.labelSmall?.copyWith(
//                       // AppColors.hint — #767676
//                       color: const Color(0xFF767676),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (isMe) const SizedBox(width: 8),
//         ],
//       ),
//     );
//   }
// }

// // ── Input bar ─────────────────────────────────────────────────────────────────
// // Group chat input bar has no attach button (file sharing is session-notes feature).

// class _InputBar extends StatelessWidget {
//   final TextEditingController controller;
//   final VoidCallback onSend;

//   const _InputBar({required this.controller, required this.onSend});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 8,
//         right: 8,
//         top: 8,
//         bottom: MediaQuery.of(context).padding.bottom + 8,
//       ),
//       decoration: const BoxDecoration(
//         // AppColors.surface — #F8F7FF
//         color: Color(0xFFF8F7FF),
//         border: Border(
//           top: BorderSide(
//             // AppColors.border — #D4D4D4
//             color: Color(0xFFD4D4D4),
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 4),
//           Expanded(
//             child: TextField(
//               controller: controller,
//               textInputAction: TextInputAction.send,
//               onSubmitted: (_) => onSend(),
//               decoration: const InputDecoration(
//                 hintText: 'Type a message...',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.all(Radius.circular(24)),
//                   // AppColors.border — #D4D4D4
//                   borderSide: BorderSide(color: Color(0xFFD4D4D4)),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.all(Radius.circular(24)),
//                   // AppColors.border — #D4D4D4
//                   borderSide: BorderSide(color: Color(0xFFD4D4D4)),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.all(Radius.circular(24)),
//                   // AppColors.accent — #894DEF
//                   borderSide: BorderSide(color: Color(0xFF894DEF), width: 1.5),
//                 ),
//                 contentPadding: EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 10,
//                 ),
//                 isDense: true,
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.send_rounded),
//             // AppColors.accent — #894DEF
//             color: const Color(0xFF894DEF),
//             onPressed: onSend,
//           ),
//         ],
//       ),
//     );
//   }
// }
