// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// import 'package:flutter/material.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   // [state] Local Uint8List preview shown immediately after picking while upload runs
//   // Cleared once Firestore reflects the new photoUrl.
//   // Uint8List? _localAvatar;
//   bool _uploadingAvatar = false;

//   // [action] Pick image → compress (flutter_image_compress, 512×512, q85) →
//   //          upload to avatars/{uid}/avatar.jpg → getDownloadURL() →
//   //          append ?v=<epoch-ms> cache-bust → updateProfile(photoUrl: url) →
//   //          clear local preview once Firestore stream emits updated photoUrl.
//   //          On failure: revert UI to previous photoUrl, show error snackbar.
//   Future<void> _pickAndUploadAvatar() async {
//     if (_uploadingAvatar) return;
//     setState(() => _uploadingAvatar = true);
//     // [ref.read(avatarUploadProvider.notifier).upload()]
//     setState(() => _uploadingAvatar = false);
//   }

//   // [action] Open EditProfileSheet as modal bottom sheet
//   void _openEditSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const EditProfileSheet(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // [state] Watch current user stream
//     // final userAsync = ref.watch(currentUserProvider);
//     // return userAsync.when(loading: ..., error: ..., data: (user) { ... });

//     final tt = Theme.of(context).textTheme;

//     // Stub values for layout reference:
//     const username = 'Student Name';
//     const email = 'user@mail.kmutt.ac.th';
//     const bio = '';
//     const faculty = 'Engineering';
//     const studentYear = 2;
//     const academicLevelDisplay = 'Undergraduate';
//     const sessionsCount = 0;
//     const friendsCount = 0;
//     const profilePhotoUrl = '';

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: const Color(0xFFFFFFFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         titleSpacing: 20,
//         title: const Text('Profile'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.settings_outlined),
//             onPressed: () => Navigator.pushNamed(context, '/settings'),
//           ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
//         children: [
//           // Avatar + name + email
//           Center(
//             child: Column(
//               children: [
//                 // [action] Tap opens image picker; disabled while upload is in progress
//                 GestureDetector(
//                   onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
//                   child: Stack(
//                     children: [
//                       CircleAvatar(
//                         radius: 40,
//                         // AppColors.accent — #894DEF at 15% opacity
//                         backgroundColor:
//                             const Color(0xFF894DEF).withValues(alpha: 0.15),
//                         // [local file image from picked path shown while uploading]
//                         // [cached network image from profilePhotoUrl once uploaded]
//                         backgroundImage: profilePhotoUrl.isNotEmpty
//                             ? NetworkImage(profilePhotoUrl)
//                             : null,
//                         child: profilePhotoUrl.isEmpty
//                             ? Text(
//                                 username.isNotEmpty
//                                     ? username[0].toUpperCase()
//                                     : '?',
//                                 style: const TextStyle(
//                                   fontSize: 28,
//                                   fontWeight: FontWeight.w700,
//                                   // AppColors.accent — #894DEF
//                                   color: Color(0xFF894DEF),
//                                 ),
//                               )
//                             : null,
//                       ),
//                       if (_uploadingAvatar)
//                         const Positioned.fill(
//                           child: CircleAvatar(
//                             radius: 40,
//                             backgroundColor: Colors.black38,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       // Camera icon badge
//                       Positioned(
//                         bottom: 0,
//                         right: 0,
//                         child: Container(
//                           width: 26,
//                           height: 26,
//                           decoration: const BoxDecoration(
//                             // AppColors.accent — #894DEF
//                             color: Color(0xFF894DEF),
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(
//                             Icons.camera_alt,
//                             size: 14,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(username, style: tt.displayMedium),
//                 const SizedBox(height: 2),
//                 Text(
//                   email,
//                   style: tt.bodyMedium?.copyWith(
//                     // AppColors.hint — #767676
//                     color: const Color(0xFF767676),
//                   ),
//                 ),
//                 if (bio.isNotEmpty) ...[
//                   const SizedBox(height: 8),
//                   Text(
//                     bio,
//                     style: tt.bodyMedium?.copyWith(
//                       // AppColors.hint — #767676
//                       color: const Color(0xFF767676),
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//                 const SizedBox(height: 8),
//                 if (faculty.isNotEmpty)
//                   Text(
//                     '$faculty · Year $studentYear · $academicLevelDisplay',
//                     style: tt.labelLarge?.copyWith(
//                       // AppColors.hint — #767676
//                       color: const Color(0xFF767676),
//                     ),
//                   ),
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
//           const SizedBox(height: 24),
//           OutlinedButton.icon(
//             onPressed: _openEditSheet,
//             icon: const Icon(Icons.edit_outlined, size: 18),
//             label: const Text('Edit Profile'),
//           ),
//           const SizedBox(height: 28),
//           Text('Session History', style: tt.titleLarge),
//           const SizedBox(height: 12),
//           _SessionHistoryList(userId: 'stub-uid'),
//         ],
//       ),
//     );
//   }
// }

// // ── Subwidgets ────────────────────────────────────────────────────────────────

// class _StatItem extends StatelessWidget {
//   final String label;
//   final String value;
//   const _StatItem({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     return Column(
//       mainAxisSize: MainAxisSize.min,
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
//               // Color(0xFF894DEF) — matches AppColors.accent — #894DEF
//               color: Color(0xFF894DEF),
//               size: 20,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               'N/A',
//               // Color(0xFF894DEF) — matches AppColors.accent — #894DEF
//               // Original used GoogleFonts.poppins — replace with tt.displayMedium in rebuild
//               style: tt.displayMedium?.copyWith(color: const Color(0xFF894DEF)),
//             ),
//           ],
//         ),
//         Text(
//           'from $sessionCount sessions',
//           // Original used GoogleFonts.poppins(fontSize: 10, fontWeight: w500) — use tt.bodySmall in rebuild
//           // AppColors.hint — #767676
//           style: tt.bodySmall?.copyWith(color: const Color(0xFF767676)),
//         ),
//       ],
//     );
//   }
// }

// class _SessionHistoryList extends StatelessWidget {
//   final String userId;
//   const _SessionHistoryList({required this.userId});

//   @override
//   Widget build(BuildContext context) {
//     // [state] Watch hosted sessions stream for userId
//     // final sessionsAsync = ref.watch(hostedSessionsProvider(userId));
//     // return sessionsAsync.when(loading: ..., error: ..., data: (sessions) { ... });

//     // Loading state:
//     // return Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()));

//     // Error state:
//     // return Padding(
//     //   padding: EdgeInsets.symmetric(vertical: 32),
//     //   child: Center(child: Text('Error: $e', style: tt.bodyMedium?.copyWith(color: Color(0xFFCC0000)))),
//     //   // AppColors.error — #CC0000
//     // );

//     // Empty state:
//     return const _EmptyHistory();

//     // Data state — list of SessionCard widgets:
//     // return Column(
//     //   children: sessions.map((s) => Padding(
//     //     padding: const EdgeInsets.only(bottom: 8),
//     //     child: /* [SessionCard widget — pass session: s] */,
//     //   )).toList(),
//     // );
//   }
// }

// class _EmptyHistory extends StatelessWidget {
//   const _EmptyHistory();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 32),
//         child: Column(
//           children: [
//             const Icon(
//               Icons.history_outlined,
//               size: 48,
//               // AppColors.disabled — #DED8F7
//               color: Color(0xFFDED8F7),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'No sessions yet',
//               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                     // AppColors.hint — #767676
//                     color: const Color(0xFF767676),
//                   ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Edit Profile Bottom Sheet ─────────────────────────────────────────────────

// class EditProfileSheet extends StatefulWidget {
//   const EditProfileSheet({super.key});

//   @override
//   State<EditProfileSheet> createState() => _EditProfileSheetState();
// }

// class _EditProfileSheetState extends State<EditProfileSheet> {
//   final TextEditingController _nameCtrl = TextEditingController();
//   final TextEditingController _facultyCtrl = TextEditingController();
//   final TextEditingController _bioCtrl = TextEditingController();
//   int _studentYear = 1;
//   // [state] AcademicLevel enum: undergraduate | graduate
//   String _academicLevel = 'Undergraduate';
//   bool _saving = false;

//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     _facultyCtrl.dispose();
//     _bioCtrl.dispose();
//     super.dispose();
//   }

//   // [validation] When academic level changes, clamp year to new max.
//   // Undergraduate: 1–4. Graduate: 1–2.
//   void _onLevelChanged(String? level) {
//     if (level == null) return;
//     setState(() {
//       _academicLevel = level;
//       final maxYear = level == 'Undergraduate' ? 4 : 2;
//       if (_studentYear > maxYear) _studentYear = maxYear;
//     });
//   }

//   // [action] Validate non-empty name → call updateProfile use case →
//   //          pop sheet on success, show snackbar on error.
//   Future<void> _save() async {
//     if (_nameCtrl.text.trim().isEmpty || _saving) return;
//     setState(() => _saving = true);
//     // [ref.read(profileRepositoryProvider).updateProfile(displayName: ..., faculty: ..., bio: ..., studentYear: ..., academicLevel: ...)]
//     setState(() => _saving = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;
//     final maxYear = _academicLevel == 'Undergraduate' ? 4 : 2;

//     return Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: Container(
//         decoration: const BoxDecoration(
//           // AppColors.surface — #F8F7FF
//           color: Color(0xFFF8F7FF),
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Center(
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       // AppColors.border — #D4D4D4
//                       color: const Color(0xFFD4D4D4),
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text('Edit Profile', style: tt.displaySmall),
//                 const SizedBox(height: 20),
//                 _Field(label: 'Name', ctrl: _nameCtrl, hint: 'Your name'),
//                 const SizedBox(height: 14),
//                 _Field(
//                   label: 'Faculty',
//                   ctrl: _facultyCtrl,
//                   hint: 'e.g. Engineering',
//                 ),
//                 const SizedBox(height: 14),
//                 Text(
//                   'Academic Level',
//                   style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 6),
//                 // [state] Controlled dropdown — value = _academicLevel
//                 // [validation] Changing level clamps _studentYear via _onLevelChanged
//                 DropdownButtonFormField<String>(
//                   value: _academicLevel,
//                   items: const [
//                     DropdownMenuItem(
//                       value: 'Undergraduate',
//                       child: Text('Undergraduate'),
//                     ),
//                     DropdownMenuItem(
//                       value: 'Graduate',
//                       child: Text('Graduate'),
//                     ),
//                   ],
//                   onChanged: _onLevelChanged,
//                 ),
//                 const SizedBox(height: 14),
//                 Text(
//                   'Year',
//                   style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 6),
//                 // [state] Controlled dropdown — value = _studentYear; items generated from maxYear
//                 DropdownButtonFormField<int>(
//                   value: _studentYear,
//                   items: List.generate(maxYear, (i) => i + 1)
//                       .map(
//                         (y) =>
//                             DropdownMenuItem(value: y, child: Text('Year $y')),
//                       )
//                       .toList(),
//                   onChanged: (v) {
//                     if (v != null) setState(() => _studentYear = v);
//                   },
//                 ),
//                 const SizedBox(height: 14),
//                 _Field(
//                   label: 'Bio',
//                   ctrl: _bioCtrl,
//                   hint: 'Tell others about yourself...',
//                   maxLines: 3,
//                 ),
//                 const SizedBox(height: 24),
//                 ElevatedButton(
//                   onPressed: _saving ? null : _save,
//                   child: _saving
//                       ? const SizedBox(
//                           width: 18,
//                           height: 18,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : const Text('Save Changes'),
//                 ),
//                 const SizedBox(height: 10),
//                 OutlinedButton(
//                   onPressed: _saving ? null : () => Navigator.pop(context),
//                   child: const Text('Cancel'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _Field extends StatelessWidget {
//   final String label;
//   final TextEditingController ctrl;
//   final String hint;
//   final int maxLines;

//   const _Field({
//     required this.label,
//     required this.ctrl,
//     required this.hint,
//     this.maxLines = 1,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: Theme.of(context)
//               .textTheme
//               .labelLarge
//               ?.copyWith(fontWeight: FontWeight.w600),
//         ),
//         const SizedBox(height: 6),
//         TextField(
//           controller: ctrl,
//           maxLines: maxLines,
//           decoration: InputDecoration(hintText: hint),
//         ),
//       ],
//     );
//   }
// }
