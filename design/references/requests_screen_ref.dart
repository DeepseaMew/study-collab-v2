// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // Architecture note:
// //   In ADR 0003, join requests are a tab inside HostSessionDetailScreen — not a standalone screen.
// //   Use _RequestCard and _RequestsList here as the layout reference for that Requests tab.
// //   The outer RequestsScreen scaffold and its providers are kept for structural reference only.
// //
// // Schema notes:
// //   JoinRequest model  → new domain entity (e.g., JoinRequestEntity)
// //   Session model      → SessionEntity
// //   request.userId     → request.uid            (align with ADR 0001 field naming)
// //   request.username   → request.displayName    (ADR 0001: users/{uid}.displayName)
// //   request.profilePhotoUrl → request.photoUrl  (ADR 0001: users/{uid}.photoUrl)
// //   session.hostId     → session.hostUid        (ADR 0001)
// //   me.id              → me.uid                 (ADR 0001)
// //   NetworkImage       → CachedNetworkImageProvider  (CLAUDE.md convention)
// //   AppException       → domain sealed error class in lib/core/errors/
// //   DateFormatter.relative() → implement in lib/core/utils/ or use intl package

// // ── Requests screen ────────────────────────────────────────────────────────────
// // Host-only. No explicit route defined in old codebase — see architecture note above.

// class RequestsScreen extends StatelessWidget {
//   final String sessionId;
//   const RequestsScreen({super.key, required this.sessionId});

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionStreamProvider(sessionId) → AsyncValue<SessionEntity?>]
//     // [ref.watch sessionRequestsProvider(sessionId) → AsyncValue<List<JoinRequestEntity>>]
//     // [ref.watch currentUserProvider → me (UserEntity?)]

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
//           'Requests',
//           style: TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: // sessionAsync.when(
//           //   loading: () =>
//           const Center(child: CircularProgressIndicator()),
//       //   error: (e, _) => _ErrorBody(message: e.toString()),
//       //   data: (session) {
//       //     if (session == null) → _ErrorBody(message: 'Session not found.')
//       //     if (me == null || me.uid != session.hostUid) → _ErrorBody(message: 'Only the session host can view requests.')
//       //     return requestsAsync.when(
//       //       loading: () => Center(child: CircularProgressIndicator()),
//       //       error: (e, _) => _ErrorBody(message: e.toString()),
//       //       data: (requests) => _RequestsList(session: session, requests: requests, callerUid: me.uid),
//       //     );
//       //   },
//       // )
//     );
//   }
// }

// // ── Requests list ──────────────────────────────────────────────────────────────

// class _RequestsList extends StatelessWidget {
//   // [session: SessionEntity, requests: List<JoinRequestEntity>, callerUid: String]
//   const _RequestsList({
//     required this.session,
//     required this.requests,
//     required this.callerUid,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (requests.isEmpty) {
//       return const Center(
//         child: Padding(
//           padding: EdgeInsets.all(32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 Icons.inbox_outlined,
//                 size: 48,
//                 // AppColors.hint — #767676
//                 color: AppColors.hint,
//               ),
//               SizedBox(height: 16),
//               Text(
//                 'No pending requests',
//                 style: TextStyle(
//                   // AppColors.text — #1A1A2E
//                   color: AppColors.text,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               SizedBox(height: 8),
//               Text(
//                 'New join requests will appear here.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//       itemCount: requests.length,
//       separatorBuilder: (_, __) => const SizedBox(height: 10),
//       itemBuilder: (_, i) => _RequestCard(
//         request: requests[i],
//         session: session,
//         callerUid: callerUid,
//       ),
//     );
//   }
// }

// // ── Request card ──────────────────────────────────────────────────────────────
// // Independent loading states: approving and declining can block each other's buttons.

// class _RequestCard extends StatefulWidget {
//   // [request: JoinRequestEntity, session: SessionEntity, callerUid: String]
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
//         // ScaffoldMessenger.showSnackBar — 'Could not approve: {error message}'
//         // AppColors.error — #CC0000 background
//         // [_friendlyError: AppException.message ?? e.toString()]
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
//         // ScaffoldMessenger.showSnackBar — 'Could not decline: {error message}'
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
//     // Both buttons disabled while either operation is in flight.
//     final isWorking = _approvingLoading || _decliningLoading;

//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           // AppColors.border — #D4D4D4
//           color: AppColors.border,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── User info row ─────────────────────────────────────────────────
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 20,
//                 // AppColors.secondary — #EDE9FE
//                 backgroundColor: AppColors.secondary,
//                 // [CachedNetworkImageProvider — use cached_network_image when photoUrl != null && isNotEmpty]
//                 backgroundImage:
//                     widget.request.photoUrl != null &&
//                         widget.request.photoUrl!.isNotEmpty
//                     ? null // replace null with CachedNetworkImageProvider(widget.request.photoUrl!)
//                     : null,
//                 child: widget.request.photoUrl == null ||
//                         widget.request.photoUrl!.isEmpty
//                     ? Text(
//                         initial,
//                         style: const TextStyle(
//                           // AppColors.accent — #894DEF
//                           color: AppColors.accent,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       )
//                     : null,
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.request.displayName,
//                       style: const TextStyle(
//                         // AppColors.text — #1A1A2E
//                         color: AppColors.text,
//                         fontSize: 15,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       // [DateFormatter.relative(widget.request.requestedAt) → 'Requested X ago']
//                       'Requested ${DateFormatter.relative(widget.request.requestedAt)}',
//                       style: const TextStyle(
//                         // AppColors.hint — #767676
//                         color: AppColors.hint,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),

//           // ── Action buttons row ────────────────────────────────────────────
//           // Decline and Approve are equal-width (Expanded flex:1 each), 10px gap.
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   style: OutlinedButton.styleFrom(
//                     // AppColors.error — #CC0000
//                     side: const BorderSide(color: AppColors.error),
//                     // AppColors.error — #CC0000
//                     foregroundColor: AppColors.error,
//                     minimumSize: const Size(double.infinity, 40),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onPressed: isWorking ? null : _decline,
//                   child: _decliningLoading
//                       ? const SizedBox(
//                           width: 14,
//                           height: 14,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             // AppColors.error — #CC0000
//                             color: AppColors.error,
//                           ),
//                         )
//                       : const Text('Decline'),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     // AppColors.success — #38A169
//                     backgroundColor: AppColors.success,
//                     minimumSize: const Size(double.infinity, 40),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onPressed: isWorking ? null : _approve,
//                   child: _approvingLoading
//                       ? const SizedBox(
//                           width: 14,
//                           height: 14,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.white,
//                           ),
//                         )
//                       : const Text(
//                           'Approve',
//                           style: TextStyle(color: Colors.white),
//                         ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Error body ────────────────────────────────────────────────────────────────

// class _ErrorBody extends StatelessWidget {
//   final String message;
//   const _ErrorBody({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(
//               Icons.error_outline,
//               size: 48,
//               // AppColors.hint — #767676
//               color: AppColors.hint,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               // AppColors.hint — #767676
//               style: const TextStyle(color: AppColors.hint, fontSize: 14),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
