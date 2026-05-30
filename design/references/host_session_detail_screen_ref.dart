// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// // Host 3-dot menu actions
// enum _HostAction { edit, delete, copyLink }

// // ── Screen ─────────────────────────────────────────────────────────────────────

// class HostSessionDetailScreen extends StatefulWidget {
//   final String sessionId;

//   const HostSessionDetailScreen({super.key, required this.sessionId});

//   @override
//   State<HostSessionDetailScreen> createState() =>
//       _HostSessionDetailScreenState();
// }

// class _HostSessionDetailScreenState
//     extends State<HostSessionDetailScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController; // TabController(length: 3, vsync: this)

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionStreamProvider(sessionId) → AsyncValue<Session?>]
//     // [ref.watch sessionMembersProvider(sessionId) → AsyncValue<List<Participant>>]
//     // [ref.watch sessionRequestsProvider(sessionId) → AsyncValue<List<JoinRequest>>]
//     // [ref.watch currentUserProvider → AsyncValue<User?>]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
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
//         // 3-dot menu — visible only when sessionAsync.asData?.value != null
//         actions: [
//           PopupMenuButton<_HostAction>(
//             icon: const Icon(Icons.more_vert, color: Colors.white),
//             onSelected: (action) {
//               // edit     → context.push('/session/{id}/edit')
//               // delete   → show AlertDialog confirming deletion
//               //            AlertDialog title:   'Delete Session?'
//               //            AlertDialog content: 'This will permanently remove the session and all its data. Members will be notified.'
//               //            Cancel: OutlinedButton, Delete: ElevatedButton(backgroundColor: Color(0xFFE53E3E), fg: white)
//               //            on confirm: sessionService.deleteSession(sessionId, hostId)
//               //            on error:   SnackBar(backgroundColor: AppColors.error — #CC0000)
//               //            on success: SnackBar('Session deleted'), context.pop()
//               // copyLink → Clipboard.setData('studycollab://session/{id}')
//               //            SnackBar('Link copied!')
//             },
//             itemBuilder: (_) => const [
//               PopupMenuItem(value: _HostAction.edit, child: Text('✏️ Edit Session')),
//               PopupMenuItem(value: _HostAction.delete, child: Text('🗑️ Delete Session')),
//               PopupMenuItem(value: _HostAction.copyLink, child: Text('🔗 Copy Invite Link')),
//             ],
//           ),
//         ],
//       ),
//       // Wrap body in sessionAsync.when():
//       //   loading: Center(child: CircularProgressIndicator())
//       //   error:   Center(child: Text('Could not load session. Please try again.',
//       //                   color: AppColors.error — #CC0000, textAlign: center))
//       //   data (null session): Center(child: Text('Session not found.',
//       //                               color: AppColors.hint — #767676, fontSize: 14))
//       //   data (session): Column below
//       body: Column(
//         children: [
//           _SessionInfoCard(session: session),
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
//               Tab(text: 'Requests'),
//             ],
//           ),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _MembersTab(
//                   session: session,
//                   members: members, // [from membersAsync.asData?.value ?? []]
//                   currentUserId: currentUser?.id ?? '',
//                 ),
//                 _NotesTab(sessionId: widget.sessionId),
//                 _RequestsTab(
//                   session: session,
//                   requests: requests, // [from requestsAsync.asData?.value ?? []]
//                   currentUserId: currentUser?.id ?? '',
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Session info card ──────────────────────────────────────────────────────────

// class _SessionInfoCard extends StatelessWidget {
//   final Session session;

//   const _SessionInfoCard({required this.session});

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
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   // AppColors.accent — #894DEF
//                   color: AppColors.accent,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Text(
//                   'Hosting',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
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
//           const SizedBox(height: 10),
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

// // ── Tab 1: Members ─────────────────────────────────────────────────────────────

// class _MembersTab extends StatelessWidget {
//   final Session session;
//   final List<Participant> members;
//   final String currentUserId;

//   const _MembersTab({
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

//         // Message group button
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
//         const SizedBox(height: 12),

//         // End session button
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             // AppColors.error — #CC0000
//             backgroundColor: AppColors.error,
//             foregroundColor: Colors.white,
//             minimumSize: const Size(double.infinity, 48),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//           onPressed: () {
//             // [showModalBottomSheet(isScrollControlled: true, backgroundColor: transparent)
//             //  → _EndSessionSheet(session: session, members: members, currentUserId: currentUserId)]
//           },
//           child: const Text('End Session'),
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

// // ── Tab 2: Notes ───────────────────────────────────────────────────────────────

// class _NotesTab extends StatelessWidget {
//   final String sessionId;

//   const _NotesTab({required this.sessionId});

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

// // ── Tab 3: Requests ────────────────────────────────────────────────────────────

// class _RequestsTab extends StatelessWidget {
//   final Session session;
//   final List<JoinRequest> requests;
//   final String currentUserId;

//   const _RequestsTab({
//     required this.session,
//     required this.requests,
//     required this.currentUserId,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//       children: [
//         // Header with count badge
//         Row(
//           children: [
//             const Text(
//               'Pending requests',
//               style: TextStyle(
//                 // AppColors.text — #1A1A2E
//                 color: AppColors.text,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 '${requests.length}',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),

//         // if requests.isEmpty:
//         Center(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 32),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.inbox_outlined,
//                   size: 48,
//                   // AppColors.secondary — #EDE9FE
//                   color: AppColors.secondary,
//                 ),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'No pending requests',
//                   style: TextStyle(
//                     // AppColors.hint — #767676
//                     color: AppColors.hint,
//                     fontSize: 13,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         // else: ...requests.map((req) => _RequestCard(request: req, session: session, callerUid: currentUserId))
//       ],
//     );
//   }
// }

// class _RequestCard extends StatefulWidget {
//   final JoinRequest request;
//   final Session session;
//   final String callerUid;

//   const _RequestCard({
//     required this.request,
//     required this.session,
//     required this.callerUid,
//   });

//   @override
//   State<_RequestCard> createState() => _RequestCardState();
// }

// class _RequestCardState extends State<_RequestCard> {
//   bool _approvingLoading = false;
//   bool _decliningLoading = false;

//   // [_approve: participationService.approveRequest(session, callerUid, requestUserId, requestUsername, requestUserPhotoUrl)
//   //  on error: SnackBar('Could not approve: …', backgroundColor: AppColors.error — #CC0000)]
//   // [_decline: participationService.declineRequest(sessionId, callerUid, userId)
//   //  on error: SnackBar('Could not decline: …', backgroundColor: AppColors.error — #CC0000)]

//   @override
//   Widget build(BuildContext context) {
//     final isWorking = _approvingLoading || _decliningLoading;
//     final initial = widget.request.username.isNotEmpty
//         ? widget.request.username[0].toUpperCase()
//         : '?';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(10),
//         // AppColors.border — #D4D4D4
//         border: Border.all(color: AppColors.border),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 20,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: AppColors.secondary,
//             // [CachedNetworkImageProvider(request.profilePhotoUrl) when non-empty — use cached_network_image]
//             backgroundImage: null,
//             child: Text(
//               initial,
//               style: const TextStyle(
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.request.username,
//                   style: const TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   // [DateFormatter.relative(request.requestedAt) — e.g. "2 hours ago"]
//                   'requestedAt',
//                   style: const TextStyle(
//                     // AppColors.hint — #767676
//                     color: AppColors.hint,
//                     fontSize: 11,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           SizedBox(
//             height: 32,
//             child: OutlinedButton(
//               style: OutlinedButton.styleFrom(
//                 // AppColors.error — #CC0000
//                 side: const BorderSide(color: AppColors.error),
//                 // AppColors.error — #CC0000
//                 foregroundColor: AppColors.error,
//                 minimumSize: const Size(70, 32),
//                 padding: const EdgeInsets.symmetric(horizontal: 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               onPressed: isWorking ? null : () {}, // [_decline]
//               child: _decliningLoading
//                   ? const SizedBox(
//                       width: 14,
//                       height: 14,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         // AppColors.error — #CC0000
//                         color: AppColors.error,
//                       ),
//                     )
//                   : const Text('Decline', style: TextStyle(fontSize: 12)),
//             ),
//           ),
//           const SizedBox(width: 6),
//           SizedBox(
//             height: 32,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 // AppColors.success — #38A169
//                 backgroundColor: AppColors.success,
//                 foregroundColor: Colors.white,
//                 minimumSize: const Size(70, 32),
//                 padding: const EdgeInsets.symmetric(horizontal: 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               onPressed: isWorking ? null : () {}, // [_approve]
//               child: _approvingLoading
//                   ? const SizedBox(
//                       width: 14,
//                       height: 14,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : const Text(
//                       'Approve',
//                       style: TextStyle(fontSize: 12, color: Colors.white),
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── End Session Bottom Sheet ───────────────────────────────────────────────────

// class _EndSessionSheet extends StatefulWidget {
//   final Session session;
//   final List<Participant> members;
//   final String currentUserId;

//   const _EndSessionSheet({
//     required this.session,
//     required this.members,
//     required this.currentUserId,
//   });

//   @override
//   State<_EndSessionSheet> createState() => _EndSessionSheetState();
// }

// class _EndSessionSheetState extends State<_EndSessionSheet> {
//   final Map<String, bool> _thumbsUp = {};
//   String _searchQuery = '';

//   // Sorted list: host first, then remaining members
//   // Filtered by _searchQuery (case-insensitive username match)

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

//               // Badge (left) + X close button (right)
//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                     decoration: BoxDecoration(
//                       // AppColors.accent — #894DEF
//                       color: AppColors.accent,
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: const Text(
//                       'SESSION ENDED',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
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
//               const SizedBox(height: 8),

//               // Session title
//               Text(
//                 widget.session.title,
//                 style: const TextStyle(
//                   // AppColors.text — #1A1A2E
//                   color: AppColors.text,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(height: 4),

//               // Date + time
//               Text(
//                 // [DateFormatter.relativeDate(session.startTime) + ' · ' + DateFormatter.timeRange(startTime, endTime)]
//                 // e.g. "Today · 10:00 – 12:00"
//                 'relativeDate · timeRange',
//                 style: const TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 13,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // AppColors.border — #D4D4D4
//               const Divider(height: 1, color: AppColors.border),
//               const SizedBox(height: 12),

//               // "Anyone stand out?" heading
//               const Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   'Anyone stand out?',
//                   style: TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 4),

//               // Description
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   'There were ${widget.members.length} people in this room. Give a quick thumbs up to anyone you\'d like to study with again.',
//                   style: const TextStyle(
//                     // AppColors.hint — #767676
//                     color: AppColors.hint,
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
//               //   (isHost || isSelf) → _HostParticipantTile(participant, showHostBadge: isHost)
//               //   else               → _RateableTile(participant, isThumbsUp: _thumbsUp[id] ?? false, onToggle)
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
//                   // [call sessionService.endSession + ratingService.submitRatings(_thumbsUp map)]
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

// class _HostParticipantTile extends StatelessWidget {
//   final Participant participant;
//   final bool showHostBadge;

//   const _HostParticipantTile({
//     required this.participant,
//     required this.showHostBadge,
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
//       trailing: showHostBadge
//           ? Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Text(
//                 'Host',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             )
//           : null,
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
