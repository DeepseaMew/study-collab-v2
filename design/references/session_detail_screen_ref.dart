// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // Architecture note:
// //   This is the public/discovery session detail screen (reached from Search or Home).
// //   It is distinct from the My Sessions detail screens defined in ADR 0003:
// //     - MemberSessionDetailScreen → /my-sessions/session/:id/member
// //     - HostSessionDetailScreen   → /my-sessions/session/:id/host
// //   Route for this screen is not defined in ADR 0003 — confirm with architect.
// //
// // Schema notes:
// //   Session model       → SessionEntity (ADR 0001 + ADR 0003 amendments)
// //   Participant model   → UserEntity
// //   JoinRequest model   → JoinRequestEntity
// //   AppUser model       → UserEntity
// //   session.hostId      → session.hostUid         (ADR 0001)
// //   session.hostName    → session.hostDisplayName  (ADR 0003 new field)
// //   session.startTime   → session.scheduledAt      (ADR 0001)
// //   session.endTime     → session.scheduledEndAt   (ADR 0003 new field)
// //   session.myStatus / JoinStatus enum → compute from session fields:
// //     hostUid == me.uid              → host
// //     memberUids.contains(me.uid)    → joined
// //     pending                        → needs separate requestStatusProvider or join_requests subcollection check
// //   SessionVisibility enum → String: 'public' | 'private'  (ADR 0001)
// //   session.participantCount → session.memberUids.length    (ADR 0001; or derived entity field)
// //   session.spotsLeft       → max(0, capacity - memberUids.length)  (ADR 0003 derived)
// //   session.isFull          → memberUids.length >= capacity         (derived)
// //   session.subject.displayName / session.subject.color → Subject enum removed;
// //     use session.hashtags.firstOrNull ?? session.academicLevel for label (ADR 0003);
// //     no per-subject color — use AppColors.accent / AppColors.secondary fallback
// //   me.id / request.userId / participant uid → .uid  (ADR 0001)
// //   me.username / request.username / participant.username → .displayName  (ADR 0001)
// //   me.profilePhotoUrl / request.profilePhotoUrl / participant.profilePhotoUrl → .photoUrl  (ADR 0001)
// //   NetworkImage → CachedNetworkImageProvider  (CLAUDE.md convention)
// //   DataException / AppException → domain sealed error class in lib/core/errors/
// //   DateFormatter.relativeDate() / .timeRange() / .relative() → implement in lib/core/utils/
// //   JoinPasswordDialog → separate widget; shown via showDialog when visibility == 'private'

// enum _HostAction { edit, delete, copyLink }

// // ── Session detail screen ──────────────────────────────────────────────────────

// class SessionDetailScreen extends StatelessWidget {
//   final String sessionId;
//   const SessionDetailScreen({super.key, required this.sessionId});

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionStreamProvider(sessionId) → AsyncValue<SessionEntity?>]

//     // loading
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));

//     // error
//     return _SessionNotFoundScaffold(message: error.toString());

//     // data: session == null
//     return const _SessionNotFoundScaffold(
//       message: 'This session no longer exists.',
//     );

//     // data: session loaded
//     return _SessionDetailBody(session: session);
//   }
// }

// // ── Not-found scaffold ─────────────────────────────────────────────────────────

// class _SessionNotFoundScaffold extends StatelessWidget {
//   final String message;
//   const _SessionNotFoundScaffold({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded),
//           onPressed: () {}, // [context.pop()]
//         ),
//         title: const Text('Session'),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(
//                 Icons.error_outline,
//                 size: 48,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Session not found',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   // AppColors.text — #1A1A2E
//                   color: AppColors.text,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 message,
//                 textAlign: TextAlign.center,
//                 // AppColors.hint — #767676
//                 style: const TextStyle(color: AppColors.hint, fontSize: 14),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Main body ──────────────────────────────────────────────────────────────────

// class _SessionDetailBody extends StatelessWidget {
//   // [session: SessionEntity]
//   const _SessionDetailBody({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionMembersProvider(session.sessionId) → AsyncValue<List<UserEntity>>]
//     // [ref.watch sessionRequestsProvider(session.sessionId) → AsyncValue<List<JoinRequestEntity>>]
//     // [ref.watch currentUserProvider → me (UserEntity?)]
//     // isHost = me != null && me.uid == session.hostUid
//     // callerUid = isHost ? me.uid : null  (only used inside isHost guards)

//     // members = membersAsync.asData?.value ?? []
//     // requests = requestsAsync.asData?.value ?? []

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       body: CustomScrollView(
//         slivers: [
//           // ── App bar (pinned) ────────────────────────────────────────────────
//           SliverAppBar(
//             pinned: true,
//             // AppColors.background — #FFFFFF
//             backgroundColor: AppColors.background,
//             leading: IconButton(
//               icon: const Icon(
//                 Icons.arrow_back_ios_new_rounded,
//                 // AppColors.text — #1A1A2E
//                 color: AppColors.text,
//               ),
//               onPressed: () {}, // [context.pop()]
//             ),
//             title: Text(
//               session.title,
//               style: const TextStyle(
//                 // AppColors.text — #1A1A2E
//                 color: AppColors.text,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             // Three-dot menu shown for host only.
//             actions: [
//               if (isHost)
//                 PopupMenuButton<_HostAction>(
//                   icon: const Icon(
//                     Icons.more_vert,
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                   ),
//                   onSelected: (action) async {
//                     switch (action) {
//                       case _HostAction.edit:
//                         // [context.push('/my-sessions/session/${session.sessionId}/edit')]
//                         break;

//                       case _HostAction.delete:
//                         // showDialog → inline AlertDialog (see below)
//                         // on confirmed: [ref.read sessionRepository .deleteSession(...)]
//                         // on success: ScaffoldMessenger 'Session deleted' + context.pop()
//                         // on error: SnackBar AppColors.error #CC0000, AppException.message ?? fallback
//                         break;

//                       case _HostAction.copyLink:
//                         // Clipboard.setData(ClipboardData(text: 'studycollab://session/${session.sessionId}'))
//                         // ScaffoldMessenger 'Link copied!'
//                         break;
//                     }
//                   },
//                   itemBuilder: (_) => const [
//                     PopupMenuItem(
//                       value: _HostAction.edit,
//                       child: Text('✏️ Edit Session'),
//                     ),
//                     PopupMenuItem(
//                       value: _HostAction.delete,
//                       child: Text('🗑️ Delete Session'),
//                     ),
//                     PopupMenuItem(
//                       value: _HostAction.copyLink,
//                       child: Text('🔗 Copy Invite Link'),
//                     ),
//                   ],
//                 ),
//             ],
//           ),

//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // ── Subject pill + visibility chip ─────────────────────────
//                   const SizedBox(height: 8),
//                   _InfoChipsRow(session: session),
//                   const SizedBox(height: 16),

//                   // ── Title ──────────────────────────────────────────────────
//                   Text(
//                     session.title,
//                     style: const TextStyle(
//                       // AppColors.text — #1A1A2E
//                       color: AppColors.text,
//                       fontSize: 22,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                   const SizedBox(height: 12),

//                   // ── Host row ───────────────────────────────────────────────
//                   _HostRow(session: session),
//                   const SizedBox(height: 16),

//                   // ── Info cards ─────────────────────────────────────────────
//                   _InfoCard(
//                     icon: Icons.calendar_today_outlined,
//                     // [DateFormatter.relativeDate(session.scheduledAt)]
//                     label: DateFormatter.relativeDate(session.scheduledAt),
//                     // [DateFormatter.timeRange(session.scheduledAt, session.scheduledEndAt)]
//                     sub: DateFormatter.timeRange(
//                       session.scheduledAt,
//                       session.scheduledEndAt,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   _InfoCard(
//                     icon: Icons.location_on_outlined,
//                     label: session.location,
//                   ),
//                   const SizedBox(height: 8),
//                   _InfoCard(
//                     icon: Icons.group_outlined,
//                     label:
//                         '${session.participantCount} / ${session.capacity} members',
//                     sub: session.isFull
//                         ? 'Full'
//                         : '${session.spotsLeft} spots left',
//                   ),
//                   const SizedBox(height: 16),

//                   // ── Description ────────────────────────────────────────────
//                   if (session.description.isNotEmpty) ...[
//                     const Text(
//                       'About this session',
//                       style: TextStyle(
//                         // AppColors.text — #1A1A2E
//                         color: AppColors.text,
//                         fontSize: 15,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       session.description,
//                       style: const TextStyle(
//                         // AppColors.hint — #767676
//                         color: AppColors.hint,
//                         fontSize: 14,
//                         height: 1.6,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                   ],

//                   // ── Hashtags ───────────────────────────────────────────────
//                   if (session.hashtags.isNotEmpty) ...[
//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 6,
//                       children: session.hashtags
//                           .map((tag) => _HashtagChip(tag: tag))
//                           .toList(),
//                     ),
//                     const SizedBox(height: 16),
//                   ],

//                   // ── Capacity progress bar ──────────────────────────────────
//                   _CapacityBar(session: session),
//                   const SizedBox(height: 24),

//                   // ── Members section ────────────────────────────────────────
//                   // "See All" shown when members.length > 3; taps push /session/:id/members
//                   _SectionHeader(
//                     title: 'Members',
//                     trailingLabel: members.length > 3 ? 'See All' : null,
//                     onTrailingTap: members.length > 3
//                         ? () {}, // [context.push('/session/${session.sessionId}/members')]
//                         : null,
//                   ),
//                   const SizedBox(height: 8),
//                   // membersAsync.when:
//                   //   loading → _LoadingRow()
//                   //   error   → _ErrorRow(message: 'Could not load members')
//                   //   data    → _MembersPreviewRow(members: list.take(5).toList(), session: session)
//                   const _LoadingRow(),
//                   const SizedBox(height: 24),

//                   // ── Pending requests (host-only) ───────────────────────────
//                   // "See All" shown when requests.length > 3; taps push /session/:id/requests
//                   if (isHost) ...[
//                     _SectionHeader(
//                       title: 'Requests',
//                       trailingLabel: requests.length > 3 ? 'See All' : null,
//                       onTrailingTap: requests.length > 3
//                           ? () {} // [context.push('/session/${session.sessionId}/requests')]
//                           : null,
//                     ),
//                     const SizedBox(height: 8),
//                     // requestsAsync.when:
//                     //   loading → _LoadingRow()
//                     //   error   → _ErrorRow(message: 'Could not load requests')
//                     //   data(empty) → Padding(vertical: 8) Text('No pending requests.' AppColors.hint #767676, fontSize: 13)
//                     //   data(list) → Column of list.take(3).map(_RequestTile(..., callerUid: callerUid!))
//                     const _LoadingRow(),
//                     const SizedBox(height: 24),
//                   ],

//                   // ── Action button row ──────────────────────────────────────
//                   // Shown for all users; host case renders Message Group button.
//                   _JoinActionRow(session: session, me: me),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Delete confirmation dialog (inline, used from PopupMenu) ──────────────────
// // Note: this version uses Theme.of(ctx).textTheme — no explicit color tokens.
// // Color(0xFFE53E3E) hardcoded red on the Delete ElevatedButton (not AppColors.error).

// Widget _buildDeleteDialog(BuildContext ctx) {
//   return AlertDialog(
//     title: Text(
//       'Delete Session?',
//       style: Theme.of(ctx).textTheme.titleLarge,
//     ),
//     content: Text(
//       'This will permanently remove the session and all its data. Members will be notified.',
//       style: Theme.of(ctx).textTheme.bodyMedium,
//     ),
//     actions: [
//       OutlinedButton(
//         onPressed: () => Navigator.pop(ctx, false),
//         child: const Text('Cancel'),
//       ),
//       ElevatedButton(
//         style: ElevatedButton.styleFrom(
//           // Color(0xFFE53E3E) — hardcoded red, intentionally different from AppColors.error #CC0000
//           backgroundColor: const Color(0xFFE53E3E),
//           foregroundColor: Colors.white,
//         ),
//         onPressed: () => Navigator.pop(ctx, true),
//         child: const Text('Delete'),
//       ),
//     ],
//   );
// }

// // ── Info chips row (subject tag + visibility) ──────────────────────────────────
// // Subject enum removed — use session.hashtags.firstOrNull ?? session.academicLevel for label.
// // Subject color removed — use AppColors.accent / AppColors.secondary as fallback.

// class _InfoChipsRow extends StatelessWidget {
//   // [session: SessionEntity]
//   const _InfoChipsRow({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     // [visibilityLabel: session.visibility == 'private' ? '🔒 Private' : '🌐 Public']
//     final subjectLabel =
//         session.hashtags.firstOrNull ?? session.academicLevel; // ADR 0003 adaptation

//     return Wrap(
//       spacing: 8,
//       runSpacing: 6,
//       children: [
//         // Subject pill — old code used session.subject.color; use AppColors.accent with 0.12 opacity
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//           decoration: BoxDecoration(
//             // AppColors.accent — #894DEF at 0.12 opacity
//             color: AppColors.accent.withValues(alpha: 0.12),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//               // AppColors.accent — #894DEF at 0.25 opacity
//               color: AppColors.accent.withValues(alpha: 0.25),
//             ),
//           ),
//           child: Text(
//             subjectLabel,
//             style: const TextStyle(
//               // AppColors.accent — #894DEF
//               color: AppColors.accent,
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         // Visibility chip
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//           decoration: BoxDecoration(
//             // AppColors.secondary — #EDE9FE
//             color: AppColors.secondary,
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Text(
//             visibilityLabel,
//             style: const TextStyle(
//               // AppColors.text — #1A1A2E
//               color: AppColors.text,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Host row ───────────────────────────────────────────────────────────────────
// // Tappable — navigates to host profile page (route not yet defined in ADRs).
// // Old code used session.subject.color for avatar background/text; use AppColors.accent fallback.

// class _HostRow extends StatelessWidget {
//   // [session: SessionEntity]
//   const _HostRow({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     final initial = session.hostDisplayName.isNotEmpty
//         ? session.hostDisplayName[0].toUpperCase()
//         : '?';

//     return GestureDetector(
//       onTap: () {}, // [context.push('/user/${session.hostUid}')]
//       behavior: HitTestBehavior.opaque,
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             // AppColors.accent — #894DEF at 0.15 opacity (replaces subject.color)
//             backgroundColor: AppColors.accent.withValues(alpha: 0.15),
//             // [CachedNetworkImageProvider — use cached_network_image when hostPhotoUrl != null && isNotEmpty]
//             backgroundImage:
//                 session.hostPhotoUrl != null && session.hostPhotoUrl!.isNotEmpty
//                 ? null // replace null with CachedNetworkImageProvider(session.hostPhotoUrl!)
//                 : null,
//             child: session.hostPhotoUrl == null || session.hostPhotoUrl!.isEmpty
//                 ? Text(
//                     initial,
//                     style: const TextStyle(
//                       // AppColors.accent — #894DEF (replaces subject.color)
//                       color: AppColors.accent,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   )
//                 : null,
//           ),
//           const SizedBox(width: 10),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Hosted by',
//                 // AppColors.hint — #767676
//                 style: TextStyle(color: AppColors.hint, fontSize: 11),
//               ),
//               Text(
//                 session.hostDisplayName,
//                 style: const TextStyle(
//                   // AppColors.text — #1A1A2E
//                   color: AppColors.text,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Info card ──────────────────────────────────────────────────────────────────

// class _InfoCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String? sub;
//   const _InfoCard({required this.icon, required this.label, this.sub});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           // AppColors.border — #D4D4D4
//           color: AppColors.border,
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             icon,
//             size: 18,
//             // AppColors.accent — #894DEF
//             color: AppColors.accent,
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 if (sub != null)
//                   Text(
//                     sub!,
//                     // AppColors.hint — #767676
//                     style: const TextStyle(color: AppColors.hint, fontSize: 12),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Hashtag chip ───────────────────────────────────────────────────────────────

// class _HashtagChip extends StatelessWidget {
//   final String tag;
//   const _HashtagChip({required this.tag});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         // AppColors.secondary — #EDE9FE
//         color: AppColors.secondary,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(
//         '#$tag',
//         style: const TextStyle(
//           // AppColors.accent — #894DEF
//           color: AppColors.accent,
//           fontSize: 12,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//     );
//   }
// }

// // ── Capacity progress bar ──────────────────────────────────────────────────────

// class _CapacityBar extends StatelessWidget {
//   // [session: SessionEntity]
//   const _CapacityBar({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     final progress = session.capacity > 0
//         ? (session.participantCount / session.capacity).clamp(0.0, 1.0)
//         : 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(4),
//           child: LinearProgressIndicator(
//             value: progress,
//             // AppColors.accent — #894DEF
//             color: AppColors.accent,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: AppColors.secondary,
//             minHeight: 6,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           '${session.spotsLeft} / ${session.capacity} spots remaining',
//           // AppColors.hint — #767676
//           style: const TextStyle(color: AppColors.hint, fontSize: 11),
//         ),
//       ],
//     );
//   }
// }

// // ── Section header ─────────────────────────────────────────────────────────────

// class _SectionHeader extends StatelessWidget {
//   final String title;
//   final String? trailingLabel;
//   final VoidCallback? onTrailingTap;
//   const _SectionHeader({
//     required this.title,
//     this.trailingLabel,
//     this.onTrailingTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 15,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         if (trailingLabel != null)
//           GestureDetector(
//             onTap: onTrailingTap,
//             child: Text(
//               trailingLabel!,
//               style: const TextStyle(
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }

// // ── Members preview row (up to 5 avatars) ─────────────────────────────────────

// class _MembersPreviewRow extends StatelessWidget {
//   // [members: List<UserEntity> (up to 5), session: SessionEntity]
//   const _MembersPreviewRow({required this.members, required this.session});

//   @override
//   Widget build(BuildContext context) {
//     if (members.isEmpty) {
//       return const Text(
//         'No members yet.',
//         // AppColors.hint — #767676
//         style: TextStyle(color: AppColors.hint, fontSize: 13),
//       );
//     }
//     return Row(
//       children: [
//         ...members.map(
//           (m) => Padding(
//             padding: const EdgeInsets.only(right: 6),
//             child: _MemberAvatar(member: m),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _MemberAvatar extends StatelessWidget {
//   // [member: UserEntity]
//   const _MemberAvatar({required this.member});

//   @override
//   Widget build(BuildContext context) {
//     final initial = member.displayName.isNotEmpty
//         ? member.displayName[0].toUpperCase()
//         : '?';
//     return Tooltip(
//       message: member.displayName,
//       child: CircleAvatar(
//         radius: 20,
//         // AppColors.secondary — #EDE9FE
//         backgroundColor: AppColors.secondary,
//         // [CachedNetworkImageProvider — use cached_network_image when photoUrl != null && isNotEmpty]
//         backgroundImage:
//             member.photoUrl != null && member.photoUrl!.isNotEmpty
//             ? null // replace null with CachedNetworkImageProvider(member.photoUrl!)
//             : null,
//         child: member.photoUrl == null || member.photoUrl!.isEmpty
//             ? Text(
//                 initial,
//                 style: const TextStyle(
//                   // AppColors.accent — #894DEF
//                   color: AppColors.accent,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                 ),
//               )
//             : null,
//       ),
//     );
//   }
// }

// // ── Request tile (compact inline layout — shown in preview list, up to 3) ─────
// // This is the compact row variant. For the full-screen requests list card layout
// // see design/references/requests_screen_ref.dart → _RequestCard.
// // Differences: avatar radius 18 (vs 20), buttons are SizedBox(height:32) inline (vs Expanded row).

// class _RequestTile extends StatefulWidget {
//   // [request: JoinRequestEntity, session: SessionEntity, callerUid: String]
//   const _RequestTile({
//     required this.request,
//     required this.session,
//     required this.callerUid,
//   });

//   @override
//   State<_RequestTile> createState() => _RequestTileState();
// }

// class _RequestTileState extends State<_RequestTile> {
//   bool _approvingLoading = false;
//   bool _decliningLoading = false;

//   Future<void> _approve() async {
//     setState(() => _approvingLoading = true);
//     try {
//       // [ref.read sessionRepository .approveRequest(
//       //   session: widget.session,
//       //   callerUid: widget.callerUid,
//       //   requestUid: widget.request.uid,
//       //   requestDisplayName: widget.request.displayName,
//       //   requestPhotoUrl: widget.request.photoUrl,
//       // )]
//       // [fire analytics: session_request_approved — payload: session_id]
//     } catch (e) {
//       if (mounted) {
//         // SnackBar: 'Could not approve request: {AppException.message ?? e.toString()}'
//         // AppColors.error — #CC0000 background
//       }
//     } finally {
//       if (mounted) setState(() => _approvingLoading = false);
//     }
//   }

//   Future<void> _decline() async {
//     // [guard: callerUid.isEmpty → show 'You must be signed in' snackbar and return]
//     setState(() => _decliningLoading = true);
//     try {
//       // [ref.read sessionRepository .declineRequest(
//       //   sessionId: widget.session.sessionId,
//       //   callerUid: widget.callerUid,
//       //   uid: widget.request.uid,
//       // )]
//       // [fire analytics: session_request_declined — payload: session_id]
//     } catch (e) {
//       if (mounted) {
//         // SnackBar: 'Could not decline request: {AppException.message ?? e.toString()}'
//         // AppColors.error — #CC0000 background
//       }
//     } finally {
//       if (mounted) setState(() => _decliningLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final initial = widget.request.displayName.isNotEmpty
//         ? widget.request.displayName[0].toUpperCase()
//         : '?';
//     final isWorking = _approvingLoading || _decliningLoading;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           // AppColors.border — #D4D4D4
//           color: AppColors.border,
//         ),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             // AppColors.secondary — #EDE9FE
//             backgroundColor: AppColors.secondary,
//             // [CachedNetworkImageProvider — use cached_network_image when photoUrl != null && isNotEmpty]
//             backgroundImage:
//                 widget.request.photoUrl != null &&
//                     widget.request.photoUrl!.isNotEmpty
//                 ? null // replace null with CachedNetworkImageProvider(widget.request.photoUrl!)
//                 : null,
//             child: widget.request.photoUrl == null ||
//                     widget.request.photoUrl!.isEmpty
//                 ? Text(
//                     initial,
//                     style: const TextStyle(
//                       // AppColors.accent — #894DEF
//                       color: AppColors.accent,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   )
//                 : null,
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.request.displayName,
//                   style: const TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   // [DateFormatter.relative(widget.request.requestedAt)]
//                   DateFormatter.relative(widget.request.requestedAt),
//                   // AppColors.hint — #767676
//                   style: const TextStyle(color: AppColors.hint, fontSize: 11),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           // Decline — compact SizedBox(height:32), 70px min width
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
//               onPressed: isWorking ? null : _decline,
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
//           // Approve — compact SizedBox(height:32), 70px min width
//           SizedBox(
//             height: 32,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 // AppColors.success — #38A169
//                 backgroundColor: AppColors.success,
//                 minimumSize: const Size(70, 32),
//                 padding: const EdgeInsets.symmetric(horizontal: 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               onPressed: isWorking ? null : _approve,
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

// // ── Join action row ────────────────────────────────────────────────────────────
// // Switches on the current user's join status relative to the session.
// // Old code used JoinStatus enum; new stack must compute status from session fields.

// class _JoinActionRow extends StatelessWidget {
//   // [session: SessionEntity, me: UserEntity?]
//   const _JoinActionRow({required this.session, required this.me});

//   @override
//   Widget build(BuildContext context) {
//     // [compute joinStatus from session + me:
//     //   if me == null            → treat as notJoined
//     //   hostUid == me.uid        → host
//     //   memberUids.contains(uid) → joined
//     //   pending check            → needs requestStatusProvider or subcollection read
//     //   else                     → notJoined]

//     // case joined:
//     return const _StatusChip(
//       label: 'Joined ✓',
//       // AppColors.success — #38A169
//       backgroundColor: AppColors.success,
//       textColor: Colors.white,
//     );

//     // case host — Message Group button navigates to group chat
//     return ElevatedButton.icon(
//       style: ElevatedButton.styleFrom(
//         // AppColors.secondary — #EDE9FE
//         backgroundColor: AppColors.secondary,
//         // AppColors.hint — #767676
//         foregroundColor: AppColors.hint,
//         minimumSize: const Size(double.infinity, 48),
//       ),
//       onPressed: () {}, // [context.push('/session/${session.sessionId}/chat')]
//       icon: const Icon(Icons.message_outlined, size: 18),
//       label: const Text('Message Group'),
//     );

//     // case pending:
//     return const _StatusChip(
//       label: 'Pending...',
//       // AppColors.warning — #D69E2E
//       backgroundColor: AppColors.warning,
//       textColor: Colors.white,
//     );

//     // case notJoined:
//     return _NotJoinedActions(session: session, me: me);
//   }
// }

// // ── Not-joined actions ─────────────────────────────────────────────────────────
// // Private session → "Join with Password" (shows JoinPasswordDialog).
// // Public session  → "Request to Join" (sends join request, stream reflects pending).

// class _NotJoinedActions extends StatefulWidget {
//   // [session: SessionEntity, me: UserEntity?]
//   const _NotJoinedActions({required this.session, required this.me});

//   @override
//   State<_NotJoinedActions> createState() => _NotJoinedActionsState();
// }

// class _NotJoinedActionsState extends State<_NotJoinedActions> {
//   bool _loading = false;

//   Future<void> _requestJoin() async {
//     // [me = widget.me ?? ref.read(currentUserProvider).asData?.value; return if null]
//     setState(() => _loading = true);
//     try {
//       // [ref.read sessionRepository .requestJoin(
//       //   sessionId: widget.session.sessionId,
//       //   uid: me.uid,
//       //   displayName: me.displayName,
//       //   photoUrl: me.photoUrl,
//       // )]
//       // Stream update from sessionStreamProvider will reflect pending status automatically.
//     } catch (e) {
//       if (mounted) {
//         // SnackBar: DataException.message ?? e.toString()
//         // AppColors.error — #CC0000 background
//       }
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<void> _joinWithPassword() async {
//     // [me = widget.me ?? ref.read(currentUserProvider).asData?.value; return if null]

//     // [showDialog → JoinPasswordDialog(session: widget.session) → returns String? password]
//     // if password == null || password.isEmpty → return

//     setState(() => _loading = true);
//     try {
//       // [ref.read sessionRepository .joinWithPassword(
//       //   session: widget.session,
//       //   uid: me.uid,
//       //   displayName: me.displayName,
//       //   photoUrl: me.photoUrl,
//       //   plainTextPassword: password,
//       // )]
//       // Stream update will reflect joined status automatically.
//     } catch (e) {
//       if (mounted) {
//         // SnackBar: DataException.message ?? e.toString()
//         // AppColors.error — #CC0000 background
//       }
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Private session
//     if (widget.session.visibility == 'private') {
//       return ElevatedButton.icon(
//         style: ElevatedButton.styleFrom(
//           // AppColors.accent — #894DEF
//           backgroundColor: AppColors.accent,
//           minimumSize: const Size(double.infinity, 48),
//         ),
//         onPressed: _loading ? null : _joinWithPassword,
//         icon: _loading
//             ? const SizedBox(
//                 width: 16,
//                 height: 16,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//             : const Icon(Icons.lock_outline, size: 16),
//         label: const Text('Join with Password'),
//       );
//     }

//     // Public session
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         // AppColors.accent — #894DEF
//         backgroundColor: AppColors.accent,
//         minimumSize: const Size(double.infinity, 48),
//       ),
//       onPressed: _loading ? null : _requestJoin,
//       child: _loading
//           ? const SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//               ),
//             )
//           : const Text('Request to Join'),
//     );
//   }
// }

// // ── Status chip ────────────────────────────────────────────────────────────────

// class _StatusChip extends StatelessWidget {
//   final String label;
//   final Color backgroundColor;
//   final Color textColor;
//   const _StatusChip({
//     required this.label,
//     required this.backgroundColor,
//     required this.textColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       decoration: BoxDecoration(
//         color: backgroundColor,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Text(
//         label,
//         textAlign: TextAlign.center,
//         style: TextStyle(
//           color: textColor,
//           fontSize: 14,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// // ── Loading / error inline placeholders ───────────────────────────────────────

// class _LoadingRow extends StatelessWidget {
//   const _LoadingRow();

//   @override
//   Widget build(BuildContext context) {
//     return const Padding(
//       padding: EdgeInsets.symmetric(vertical: 12),
//       child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
//     );
//   }
// }

// class _ErrorRow extends StatelessWidget {
//   final String message;
//   const _ErrorRow({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Text(
//         message,
//         // AppColors.hint — #767676
//         style: const TextStyle(color: AppColors.hint, fontSize: 13),
//       ),
//     );
//   }
// }
