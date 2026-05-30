// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// // ── Screen ─────────────────────────────────────────────────────────────────────

// class MemberSessionDetailScreen extends StatefulWidget {
//   final String sessionId;

//   const MemberSessionDetailScreen({super.key, required this.sessionId});

//   @override
//   State<MemberSessionDetailScreen> createState() =>
//       _MemberSessionDetailScreenState();
// }

// class _MemberSessionDetailScreenState
//     extends State<MemberSessionDetailScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController; // TabController(length: 2, vsync: this)
//   bool _sessionEndedPopupShown = false;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   void _showSessionEndedPopup(
//     Session session,
//     List<Participant> members,
//     String currentUserId,
//   ) {
//     showModalBottomSheet<void>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       isDismissible: false, // non-dismissible — user must submit or close
//       builder: (_) => _SessionEndedSheet(
//         session: session,
//         members: members,
//         currentUserId: currentUserId,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionStreamProvider(sessionId) → AsyncValue<Session?>]
//     // [ref.watch sessionMembersProvider(sessionId) → AsyncValue<List<Participant>>]
//     // [ref.watch currentUserProvider → AsyncValue<User?>]

//     // [ref.listen sessionStreamProvider(sessionId):
//     //   when session.status transitions to 'ended' (ADR 0001 status enum, maps to
//     //   old SessionStatus.completed) AND _sessionEndedPopupShown == false:
//     //     setState(() => _sessionEndedPopupShown = true)
//     //     WidgetsBinding.instance.addPostFrameCallback((_) {
//     //       if (mounted) _showSessionEndedPopup(session, members, currentUserId)
//     //     })]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         // No actions menu — member view has no 3-dot menu
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [
//                 Color(0xFF7143BF),
//                 // AppColors.accent — #894DEF
//                 AppColors.accent,
//               ],
//             ),
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
//           onPressed: () {}, // [context.pop()]
//         ),
//         title: const Text(
//           'Session Details',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//             fontSize: 18,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       // sessionAsync.when(
//       //   loading: Center(child: CircularProgressIndicator())
//       //   error:   Center(child: Text('Could not load session. Please try again.',
//       //                   color: AppColors.error — #CC0000, textAlign: center))
//       //   data (null): Center(child: Text('Session not found.',
//       //                       color: AppColors.hint — #767676, fontSize: 14))
//       //   data (session): Column below
//       body: Column(
//         children: [
//           _MemberSessionInfoCard(session: session),
//           TabBar(
//             controller: _tabController,
//             // AppColors.accent — #894DEF
//             indicatorColor: AppColors.accent,
//             // AppColors.accent — #894DEF
//             labelColor: AppColors.accent,
//             // AppColors.hint — #767676
//             unselectedLabelColor: AppColors.hint,
//             labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
//             unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
//             tabs: const [
//               Tab(text: 'Members'),
//               Tab(text: 'Notes'),
//             ],
//           ),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _MemberMembersTab(
//                   session: session,
//                   members: members, // [from membersAsync.asData?.value ?? []]
//                   currentUserId: currentUserId, // [from currentUserProvider]
//                 ),
//                 _MemberNotesTab(sessionId: widget.sessionId),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Session info card (member view) ───────────────────────────────────────────

// class _MemberSessionInfoCard extends StatelessWidget {
//   final Session session;

//   const _MemberSessionInfoCard({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     // progress = (session.participantCount / session.capacity).clamp(0.0, 1.0)
//     // or 0.0 when capacity == 0
//     final progress = session.capacity > 0
//         ? (session.participantCount / session.capacity).clamp(0.0, 1.0)
//         : 0.0;

//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Tags row
//           Row(
//             children: [
//               _SubjectChip(session: session),
//               const SizedBox(width: 8),
//               // "Joined" badge — AppColors.success — #38A169
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   // AppColors.success — #38A169
//                   color: AppColors.success,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.check_rounded, color: Colors.white, size: 13),
//                     SizedBox(width: 4),
//                     Text(
//                       'Joined',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           // Session title
//           Text(
//             session.title,
//             style: const TextStyle(
//               // AppColors.text — #1A1A2E
//               color: AppColors.text,
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 8),
//           // Host row — small avatar + "Hosted by {hostName}"
//           Row(
//             children: [
//               _ParticipantAvatar(
//                 username: session.hostName,
//                 photoUrl: session.hostPhotoUrl,
//                 radius: 12,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 'Hosted by ${session.hostName}',
//                 style: const TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 13,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           // Date row
//           Row(
//             children: [
//               const Icon(
//                 Icons.calendar_today_outlined,
//                 size: 14,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 // [DateFormatter.relativeDate(session.startTime) + '  ' + DateFormatter.timeRange(session.startTime, session.endTime)]
//                 // e.g. "Today  10:00 – 12:00"
//                 'relativeDate  timeRange',
//                 style: const TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 13,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           // Location row
//           Row(
//             children: [
//               const Icon(
//                 Icons.location_on_outlined,
//                 size: 14,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: Text(
//                   session.location,
//                   style: const TextStyle(
//                     // AppColors.hint — #767676
//                     color: AppColors.hint,
//                     fontSize: 13,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           // Capacity row
//           Row(
//             children: [
//               const Icon(
//                 Icons.group_outlined,
//                 size: 14,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 '${session.participantCount}/${session.capacity} members',
//                 style: const TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 13,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           // Progress bar
//           ClipRRect(
//             borderRadius: BorderRadius.circular(4),
//             child: LinearProgressIndicator(
//               value: progress,
//               // AppColors.accent — #894DEF
//               color: AppColors.accent,
//               // AppColors.secondary — #EDE9FE
//               backgroundColor: AppColors.secondary,
//               minHeight: 6,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SubjectChip extends StatelessWidget {
//   final Session session;

//   const _SubjectChip({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     // session.subject.color is a runtime Color from the session's subject data
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: session.subject.color.withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: session.subject.color.withValues(alpha: 0.25),
//         ),
//       ),
//       child: Text(
//         session.subject.displayName,
//         style: TextStyle(
//           color: session.subject.color,
//           fontSize: 12,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// // ── Tab 1: Members (member view) ──────────────────────────────────────────────

// class _MemberMembersTab extends StatelessWidget {
//   final Session session;
//   final List<Participant> members;
//   final String currentUserId;

//   const _MemberMembersTab({
//     required this.session,
//     required this.members,
//     required this.currentUserId,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final hostParticipant = members.where((m) => m.isHost).firstOrNull;
//     final nonHostMembers = members.where((m) => !m.isHost).toList();
//     final previewMembers = nonHostMembers.take(5).toList();

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//       children: [
//         // Host section label
//         const Text(
//           'Host',
//           style: TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         const SizedBox(height: 8),
//         _HostRow(session: session, hostParticipant: hostParticipant),
//         const SizedBox(height: 20),

//         // Members section header
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'Members (${nonHostMembers.length})',
//               style: const TextStyle(
//                 // AppColors.text — #1A1A2E
//                 color: AppColors.text,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             TextButton(
//               onPressed: () {}, // [context.push('/session/{id}/members')]
//               child: const Text(
//                 'View all',
//                 style: TextStyle(
//                   // AppColors.accent — #894DEF
//                   color: AppColors.accent,
//                   fontSize: 13,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         // if nonHostMembers.isEmpty:
//         //   Text('No members yet.', color: AppColors.hint — #767676, fontSize: 13)
//         // else: Row of up to 5 avatar bubbles (previewMembers)
//         Row(
//           children: previewMembers
//               .map(
//                 (m) => Padding(
//                   padding: const EdgeInsets.only(right: 6),
//                   child: _ParticipantAvatar(
//                     username: m.username,
//                     photoUrl: m.profilePhotoUrl,
//                     radius: 20,
//                   ),
//                 ),
//               )
//               .toList(),
//         ),
//         const SizedBox(height: 32),

//         // Message group button — only CTA in member tab (no End Session button)
//         ElevatedButton.icon(
//           style: ElevatedButton.styleFrom(
//             // AppColors.accent — #894DEF
//             backgroundColor: AppColors.accent,
//             minimumSize: const Size(double.infinity, 48),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//           icon: const Icon(Icons.chat_bubble_outline, size: 18),
//           label: const Text('Message group'),
//           onPressed: () {}, // [navigate to group chat for this session]
//         ),
//       ],
//     );
//   }
// }

// class _HostRow extends StatelessWidget {
//   final Session session;
//   final Participant? hostParticipant;

//   const _HostRow({required this.session, this.hostParticipant});

//   @override
//   Widget build(BuildContext context) {
//     // name     = hostParticipant?.username     ?? session.hostName
//     // photoUrl = hostParticipant?.profilePhotoUrl ?? session.hostPhotoUrl
//     return Row(
//       children: [
//         _ParticipantAvatar(username: name, photoUrl: photoUrl, radius: 20),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Text(
//             name,
//             style: const TextStyle(
//               // AppColors.text — #1A1A2E
//               color: AppColors.text,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//           decoration: BoxDecoration(
//             // AppColors.accent — #894DEF
//             color: AppColors.accent,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: const Text(
//             'Host',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Tab 2: Notes (identical layout to host notes tab) ─────────────────────────

// class _MemberNotesTab extends StatelessWidget {
//   final String sessionId;

//   const _MemberNotesTab({required this.sessionId});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//       child: Column(
//         children: [
//           // Search bar
//           TextField(
//             decoration: InputDecoration(
//               hintText: 'Search notes...',
//               prefixIcon: const Icon(
//                 Icons.search_outlined,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               filled: true,
//               // AppColors.surface — hex unknown (not in app_colors.dart)
//               fillColor: AppColors.surface,
//               contentPadding: const EdgeInsets.symmetric(vertical: 12),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 // AppColors.border — #D4D4D4
//                 borderSide: const BorderSide(color: AppColors.border),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 // AppColors.border — #D4D4D4
//                 borderSide: const BorderSide(color: AppColors.border),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 // AppColors.accent — #894DEF
//                 borderSide: const BorderSide(color: AppColors.accent, width: 2),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Empty state (shown when no notes uploaded)
//           Expanded(
//             child: Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     Icons.description_outlined,
//                     size: 64,
//                     // AppColors.secondary — #EDE9FE
//                     color: AppColors.secondary,
//                   ),
//                   const SizedBox(height: 12),
//                   const Text(
//                     'No notes uploaded yet',
//                     style: TextStyle(
//                       // AppColors.hint — #767676
//                       color: AppColors.hint,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Upload note button
//           OutlinedButton.icon(
//             style: OutlinedButton.styleFrom(
//               // AppColors.accent — #894DEF
//               foregroundColor: AppColors.accent,
//               minimumSize: const Size(double.infinity, 48),
//               // AppColors.accent — #894DEF
//               side: const BorderSide(color: AppColors.accent),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             icon: const Icon(Icons.upload_file_outlined, size: 18),
//             label: const Text('Upload Note'),
//             onPressed: () {}, // [trigger file picker and upload flow]
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Session Ended Bottom Sheet (member view) ──────────────────────────────────
// // Triggered automatically via ref.listen when session.status transitions to
// // 'ended' (ADR 0001). isDismissible: false — user must tap Submit or close (X).

// class _SessionEndedSheet extends StatefulWidget {
//   final Session session;
//   final List<Participant> members;
//   final String currentUserId;

//   const _SessionEndedSheet({
//     required this.session,
//     required this.members,
//     required this.currentUserId,
//   });

//   @override
//   State<_SessionEndedSheet> createState() => _SessionEndedSheetState();
// }

// class _SessionEndedSheetState extends State<_SessionEndedSheet> {
//   final Map<String, bool> _thumbsUp = {};
//   String _searchQuery = '';

//   // Participant sort order:
//   //   1. host (userId == session.hostId) — no thumbs-up toggle
//   //   2. self (userId == currentUserId, not host) — no thumbs-up toggle
//   //   3. others — thumbs-up toggle available

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Drag handle
//               Container(
//                 width: 40,
//                 height: 4,
//                 margin: const EdgeInsets.only(bottom: 8),
//                 decoration: BoxDecoration(
//                   // AppColors.border — #D4D4D4
//                   color: AppColors.border,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),

//               // Top row: centered "Session Ended" title + X close button (right)
//               Row(
//                 children: [
//                   const Spacer(),
//                   const Text(
//                     'Session Ended',
//                     style: TextStyle(
//                       // AppColors.text — #1A1A2E
//                       color: AppColors.text,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const Spacer(),
//                   IconButton(
//                     icon: const Icon(
//                       Icons.close,
//                       // AppColors.hint — #767676
//                       color: AppColors.hint,
//                     ),
//                     onPressed: () => Navigator.pop(context),
//                     visualDensity: VisualDensity.compact,
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 4),

//               // Session name (hint colour, smaller — subtitle role)
//               Text(
//                 widget.session.title,
//                 style: const TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 14,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 16),

//               // Description
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   'There were ${widget.members.length} people in this room. Give a quick thumbs up to anyone you\'d like to study with again.',
//                   style: const TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 13,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // Search bar
//               TextField(
//                 onChanged: (v) => setState(() => _searchQuery = v),
//                 decoration: InputDecoration(
//                   hintText: 'Search participants by name',
//                   prefixIcon: const Icon(
//                     Icons.search_outlined,
//                     // AppColors.hint — #767676
//                     color: AppColors.hint,
//                   ),
//                   filled: true,
//                   // AppColors.background — #FFFFFF
//                   fillColor: AppColors.background,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 10),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     // AppColors.border — #D4D4D4
//                     borderSide: const BorderSide(color: AppColors.border),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     // AppColors.border — #D4D4D4
//                     borderSide: const BorderSide(color: AppColors.border),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     // AppColors.accent — #894DEF
//                     borderSide: const BorderSide(color: AppColors.accent, width: 2),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 8),

//               // Participant list — max height: 30% of screen
//               // if filtered.isEmpty: Text('No participants found.', color: AppColors.hint — #767676, fontSize: 13)
//               // else ListView.builder:
//               //   isHost → _HostParticipantTile(participant)
//               //   isSelf → _SelfParticipantTile(participant)  ← shows "ME" badge
//               //   else   → _RateableTile(participant, isThumbsUp: _thumbsUp[id] ?? false, onToggle)
//               ConstrainedBox(
//                 constraints: BoxConstraints(
//                   maxHeight: MediaQuery.of(context).size.height * 0.3,
//                 ),
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: 0, // [filtered.length]
//                   itemBuilder: (ctx, i) => const SizedBox.shrink(),
//                 ),
//               ),
//               const SizedBox(height: 16),

//               // Submit ratings button
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   // AppColors.accent — #894DEF
//                   backgroundColor: AppColors.accent,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(double.infinity, 48),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 onPressed: () {
//                   // [call ratingService.submitRatings(_thumbsUp map)]
//                   // on success: Navigator.pop(context)
//                   //             SnackBar('Ratings submitted!', backgroundColor: AppColors.success — #38A169)
//                 },
//                 child: const Text('Submit Rating'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Participant tile widgets ───────────────────────────────────────────────────

// class _HostParticipantTile extends StatelessWidget {
//   final Participant participant;

//   const _HostParticipantTile({required this.participant});

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: _ParticipantAvatar(
//         username: participant.username,
//         photoUrl: participant.profilePhotoUrl,
//         radius: 20,
//       ),
//       title: Text(
//         participant.username,
//         style: const TextStyle(
//           // AppColors.text — #1A1A2E
//           color: AppColors.text,
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//       trailing: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//         decoration: BoxDecoration(
//           // AppColors.accent — #894DEF
//           color: AppColors.accent,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: const Text(
//           'Host',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // "ME" badge tile — current user who is not the host; no thumbs-up toggle
// class _SelfParticipantTile extends StatelessWidget {
//   final Participant participant;

//   const _SelfParticipantTile({required this.participant});

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: _ParticipantAvatar(
//         username: participant.username,
//         photoUrl: participant.profilePhotoUrl,
//         radius: 20,
//       ),
//       title: Text(
//         participant.username,
//         style: const TextStyle(
//           // AppColors.text — #1A1A2E
//           color: AppColors.text,
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//       trailing: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//         decoration: BoxDecoration(
//           // AppColors.hint — #767676
//           color: AppColors.hint,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: const Text(
//           'ME',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _RateableTile extends StatelessWidget {
//   final Participant participant;
//   final bool isThumbsUp;
//   final VoidCallback onToggle;

//   const _RateableTile({
//     required this.participant,
//     required this.isThumbsUp,
//     required this.onToggle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: _ParticipantAvatar(
//         username: participant.username,
//         photoUrl: participant.profilePhotoUrl,
//         radius: 20,
//       ),
//       title: Text(
//         participant.username,
//         style: const TextStyle(
//           // AppColors.text — #1A1A2E
//           color: AppColors.text,
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//       trailing: IconButton(
//         icon: Icon(
//           isThumbsUp ? Icons.thumb_up : Icons.thumb_up_outlined,
//           // AppColors.accent — #894DEF when thumbs up, AppColors.hint — #767676 otherwise
//           color: isThumbsUp ? AppColors.accent : AppColors.hint,
//         ),
//         onPressed: onToggle,
//       ),
//     );
//   }
// }

// // ── Shared helpers ─────────────────────────────────────────────────────────────

// class _ParticipantAvatar extends StatelessWidget {
//   final String username;
//   final String? photoUrl;
//   final double radius;

//   const _ParticipantAvatar({
//     required this.username,
//     required this.photoUrl,
//     required this.radius,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
//     return CircleAvatar(
//       radius: radius,
//       // AppColors.secondary — #EDE9FE
//       backgroundColor: AppColors.secondary,
//       // [CachedNetworkImageProvider(photoUrl) when non-empty — use cached_network_image]
//       backgroundImage: null,
//       child: photoUrl == null || photoUrl!.isEmpty
//           ? Text(
//               initial,
//               style: TextStyle(
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//                 fontSize: radius * 0.65,
//                 fontWeight: FontWeight.w600,
//               ),
//             )
//           : null,
//     );
//   }
// }
