// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // Schema notes:
// //   Route: /my-sessions/session/:id/edit  (old code used /session/:id/edit — align with ADR 0003)
// //   session.hostId → session.hostUid  (ADR 0001 field name)
// //   DataException → domain sealed error class in lib/core/errors/
// //   SessionForm reference: see design/references/create_session_screen_ref.dart
// //   bottomExtra slot: passes _DeleteSessionButton into SessionForm's bottom area.

// // ── Edit session screen ────────────────────────────────────────────────────────

// class EditSessionScreen extends StatelessWidget {
//   final String id;
//   const EditSessionScreen({super.key, required this.id});

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch sessionStreamProvider(id) → AsyncValue<SessionEntity?>]

//     // loading state
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));

//     // error state — DataException.message or e.toString()
//     return _ErrorScaffold(message: errorMessage);

//     // data: session == null
//     return const _ErrorScaffold(message: 'Session not found.');

//     // data: non-host guard — me == null || me.id != session.hostUid
//     return Scaffold(
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
//           'Edit Session',
//           style: TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: const Center(
//         child: Text(
//           'You are not authorized to edit this session.',
//           // AppColors.hint — #767676
//           style: TextStyle(color: AppColors.hint),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );

//     // data: session loaded and current user is host
//     // [SessionForm(isEditing: true, initialSession: session, bottomExtra: _DeleteSessionButton(sessionId: id))]
//     // SessionForm pre-fills all fields from session; see create_session_screen_ref.dart.
//   }
// }

// // ── Delete button (injected via SessionForm.bottomExtra) ──────────────────────

// class _DeleteSessionButton extends StatelessWidget {
//   final String sessionId;
//   const _DeleteSessionButton({required this.sessionId});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
//       child: TextButton(
//         style: TextButton.styleFrom(
//           // AppColors.error — #CC0000
//           foregroundColor: AppColors.error,
//           minimumSize: const Size(double.infinity, 44),
//         ),
//         onPressed: () => showDialog<void>(
//           context: context,
//           builder: (_) => _DeleteDialog(sessionId: sessionId),
//         ),
//         child: const Text(
//           'Delete Session',
//           style: TextStyle(fontWeight: FontWeight.w500),
//         ),
//       ),
//     );
//   }
// }

// // ── Delete confirmation dialog ─────────────────────────────────────────────────

// class _DeleteDialog extends StatefulWidget {
//   final String sessionId;
//   const _DeleteDialog({required this.sessionId});

//   @override
//   State<_DeleteDialog> createState() => _DeleteDialogState();
// }

// class _DeleteDialogState extends State<_DeleteDialog> {
//   bool _deleting = false;

//   Future<void> _delete() async {
//     // [ref.read currentUserProvider → me (User?); pop dialog and return if null]
//     setState(() => _deleting = true);
//     try {
//       // [ref.read sessionRepository .deleteSession(sessionId: widget.sessionId, hostUid: me.uid)]
//       // on success: Navigator.pop(context) → close dialog, then context.pop() → back to detail or home
//     } catch (e) {
//       // Navigator.pop(context) → close dialog
//       // ScaffoldMessenger.showSnackBar — AppColors.error #CC0000 background, DataException.message or e.toString()
//     } finally {
//       if (mounted) setState(() => _deleting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       // AppColors.surface — hex unknown (not in app_colors.dart)
//       backgroundColor: AppColors.surface,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       title: const Text(
//         'Delete Session',
//         style: TextStyle(
//           // AppColors.text — #1A1A2E
//           color: AppColors.text,
//           fontSize: 16,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       content: const Text(
//         'This will permanently delete the session and remove all members. '
//         'This action cannot be undone.',
//         // AppColors.hint — #767676
//         style: TextStyle(color: AppColors.hint, fontSize: 14),
//       ),
//       actions: [
//         TextButton(
//           onPressed: _deleting ? null : () => Navigator.pop(context),
//           child: const Text(
//             'Cancel',
//             // AppColors.hint — #767676
//             style: TextStyle(color: AppColors.hint),
//           ),
//         ),
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             // AppColors.error — #CC0000
//             backgroundColor: AppColors.error,
//             minimumSize: const Size(80, 40),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//           onPressed: _deleting ? null : _delete,
//           child: _deleting
//               ? const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 )
//               : const Text('Delete', style: TextStyle(color: Colors.white)),
//         ),
//       ],
//     );
//   }
// }

// // ── Error scaffold ─────────────────────────────────────────────────────────────

// class _ErrorScaffold extends StatelessWidget {
//   final String message;
//   const _ErrorScaffold({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
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
//           'Edit Session',
//           style: TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
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
