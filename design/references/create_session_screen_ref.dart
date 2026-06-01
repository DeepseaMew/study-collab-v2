// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // NOTE — schema adaptations for the Flutter Engineer:
// //   • Subject enum (old) has no equivalent in ADR 0001. _SubjectGrid shows
// //     the layout pattern; replace Subject chips with an academicLevel selector
// //     or remove Step 1 subject section entirely (hashtags in Step 3 cover tagging).
// //   • startTime / endTime → scheduledAt / scheduledEndAt (ADR 0001 + ADR 0003).
// //   • Password min length: old = 6 chars. ADR 0001 pin field min = 4 chars.
// //     Resolve with the team before implementing validation.
// //   • studentYear max: old = 4 (undergrad) / 2 (postgrad). ADR 0001 allows 1–8.
// //   • AcademicLevel.postgraduate → 'graduate' in ADR 0001 enum string.
// //   • CreateSessionScreen is a thin wrapper; all layout lives in SessionForm.
// //     Route: /create-session (declared in app_router.dart).

// // ── CreateSessionScreen (wrapper) ─────────────────────────────────────────────

// class CreateSessionScreen extends StatelessWidget {
//   const CreateSessionScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const SessionForm(isEditing: false);
//   }
// }

// // ── SessionForm ────────────────────────────────────────────────────────────────
// // Shared by create (/create-session) and edit (/session/:id/edit) flows.
// // When isEditing: true, initialSession must be provided.
// // bottomExtra: optional widget rendered below the bottom nav bar;
// //   used by EditSessionScreen to inject a Delete button.

// class SessionForm extends StatefulWidget {
//   final bool isEditing;
//   final SessionEntity? initialSession;
//   final Widget? bottomExtra;

//   const SessionForm({
//     super.key,
//     this.isEditing = false,
//     this.initialSession,
//     this.bottomExtra,
//   }) : assert(
//          !isEditing || initialSession != null,
//          'initialSession is required when isEditing is true',
//        );

//   @override
//   State<SessionForm> createState() => _SessionFormState();
// }

// class _SessionFormState extends State<SessionForm>
//     with SingleTickerProviderStateMixin {
//   // ── Step index ──────────────────────────────────────────────────────────────
//   int _step = 0;
//   static const int _totalSteps = 3;

//   // ── Step 1 — Basic info ─────────────────────────────────────────────────────
//   final _titleCtrl = TextEditingController();
//   final _descCtrl = TextEditingController();
//   // [_subject: Subject? — old enum, no ADR 0001 equivalent.
//   //  Replace with String? hashtag or AcademicLevel? selector in new stack.]

//   // ── Step 2 — Time & location ────────────────────────────────────────────────
//   DateTime _startTime = DateTime.now().add(const Duration(hours: 1)); // → scheduledAt
//   DateTime _endTime = DateTime.now().add(const Duration(hours: 3));   // → scheduledEndAt
//   final _locationCtrl = TextEditingController();

//   // ── Step 3 — Capacity, visibility & filters ─────────────────────────────────
//   int _capacity = 5; // min 2, max 50 via stepper
//   String _visSegment = 'public'; // 'public' | 'private' → visibility field
//   final _passwordCtrl = TextEditingController(); // → pin field (ADR 0001 min 4 chars)
//   bool _obscurePassword = true;

//   // Optional filters
//   int? _studentYear;      // ADR 0001 allows 1–8; old code capped at 4/2
//   String? _academicLevel; // 'undergraduate' | 'graduate' (ADR 0001 enum strings)

//   // Hashtags
//   final _hashtagCtrl = TextEditingController();
//   final List<String> _hashtags = []; // stored lowercase, free-text (ADR 0001)

//   // ── Submit state ─────────────────────────────────────────────────────────────
//   bool _submitting = false;

//   bool get _isEditing => widget.isEditing;

//   @override
//   void initState() {
//     super.initState();
//     final s = widget.initialSession;
//     if (s != null) {
//       _titleCtrl.text = s.title;
//       _descCtrl.text = s.description ?? '';
//       _startTime = s.scheduledAt.toDate();
//       _endTime = s.scheduledEndAt.toDate();
//       _locationCtrl.text = s.location;
//       _capacity = s.capacity;
//       _visSegment = s.visibility == 'private' ? 'private' : 'public';
//       _studentYear = s.studentYear;
//       _academicLevel = s.academicLevel;
//       _hashtags.addAll(s.hashtags);
//     }
//   }

//   @override
//   void dispose() {
//     _titleCtrl.dispose();
//     _descCtrl.dispose();
//     _locationCtrl.dispose();
//     _passwordCtrl.dispose();
//     _hashtagCtrl.dispose();
//     super.dispose();
//   }

//   // ── Validation ───────────────────────────────────────────────────────────────
//   // [_validate() rules:
//   //   1. title non-empty                            → 'Please enter a session title.'
//   //   2. location non-empty                         → 'Please enter a location.'
//   //   3. create only: startTime in the future       → 'Session start time must be in the future.'
//   //   4. endTime strictly after startTime           → 'End time must be after start time.'
//   //   5. capacity >= 2                              → 'Capacity must be at least 2.'
//   //   6. private + create + empty password          → 'Please enter a password for the private session.'
//   //   7. private + create + password < 6 chars      → 'Password must be at least 6 characters.'
//   //      (ADR 0001 pin min is 4 chars — reconcile with team before implementing)
//   //  All errors shown via SnackBar(backgroundColor: AppColors.error — #CC0000)]

//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         // AppColors.error — #CC0000
//         backgroundColor: AppColors.error,
//       ),
//     );
//   }

//   // ── Submit ───────────────────────────────────────────────────────────────────
//   Future<void> _submit() async {
//     // [if !_validate(): return]
//     // [ref.read currentUserProvider → me; if null: _showError('You must be signed in.')]
//     // setState(() => _submitting = true)
//     // try:
//     //   if _isEditing:
//     //     [sessionRepository.editSession(sessionId, callerUid, {
//     //       title, description, location,
//     //       scheduledAt: Timestamp, scheduledEndAt: Timestamp,
//     //       capacity, visibility, hashtags,
//     //       studentYear: value or delete if null,
//     //       academicLevel: value or delete if null,
//     //     })]
//     //   else:
//     //     [sessionRepository.createSession(SessionEntity, plainTextPin: pin if private)]
//     //   if mounted: context.pop()
//     // catch (e): _showError(...)
//     // finally: if mounted: setState(() => _submitting = false)
//   }

//   // ── Step navigation ──────────────────────────────────────────────────────────
//   void _nextStep() {
//     if (_step < _totalSteps - 1) setState(() => _step++);
//   }

//   void _prevStep() {
//     if (_step > 0) setState(() => _step--);
//   }

//   void _addHashtag() {
//     // strip '#', trim whitespace, deduplicate, add lowercase
//     final tag = _hashtagCtrl.text.trim().replaceAll('#', '').toLowerCase();
//     if (tag.isNotEmpty && !_hashtags.contains(tag)) {
//       setState(() {
//         _hashtags.add(tag);
//         _hashtagCtrl.clear();
//       });
//     }
//   }

//   // ── Build ─────────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch currentUserProvider — warm-up so canSubmit is ready on first build]

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         // AppColors.background — #FFFFFF
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//           ),
//           onPressed: () {}, // [context.pop()]
//         ),
//         title: Text(
//           _isEditing ? 'Edit Session' : 'Create Session',
//           style: const TextStyle(
//             // AppColors.text — #1A1A2E
//             color: AppColors.text,
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           // Step progress bar (3 segments, filled up to currentStep)
//           _StepProgressBar(currentStep: _step, totalSteps: _totalSteps),
//           // Animated fade-transition between steps
//           Expanded(
//             child: AnimatedSwitcher(
//               duration: const Duration(milliseconds: 250),
//               transitionBuilder: (child, animation) =>
//                   FadeTransition(opacity: animation, child: child),
//               child: _buildCurrentStep(),
//             ),
//           ),
//           // Bottom navigation: Back + Next/Save buttons
//           _BottomNav(
//             step: _step,
//             totalSteps: _totalSteps,
//             submitting: _submitting,
//             // [canSubmit: ref.watch(currentUserProvider).asData?.value != null]
//             canSubmit: true,
//             onBack: _prevStep,
//             onNext: _nextStep,
//             onSubmit: _submit,
//           ),
//           // Optional extra widget below nav (e.g. Delete button in edit mode)
//           if (widget.bottomExtra != null) widget.bottomExtra!,
//         ],
//       ),
//     );
//   }

//   Widget _buildCurrentStep() {
//     switch (_step) {
//       case 0:
//         return _Step1BasicInfo(
//           key: const ValueKey('step0'),
//           titleCtrl: _titleCtrl,
//           descCtrl: _descCtrl,
//           // [subject: old Subject enum — adapt to new schema at implementation time]
//         );
//       case 1:
//         return _Step2TimeLocation(
//           key: const ValueKey('step1'),
//           startTime: _startTime,
//           endTime: _endTime,
//           locationCtrl: _locationCtrl,
//           onStartTimeChanged: (dt) => setState(() => _startTime = dt),
//           onEndTimeChanged: (dt) => setState(() => _endTime = dt),
//         );
//       case 2:
//         return _Step3CapacityVisibility(
//           key: const ValueKey('step2'),
//           capacity: _capacity,
//           visSegment: _visSegment,
//           passwordCtrl: _passwordCtrl,
//           obscurePassword: _obscurePassword,
//           studentYear: _studentYear,
//           academicLevel: _academicLevel,
//           hashtags: _hashtags,
//           hashtagCtrl: _hashtagCtrl,
//           isEditing: _isEditing,
//           onCapacityChanged: (v) => setState(() => _capacity = v),
//           onVisSegmentChanged: (v) => setState(() => _visSegment = v),
//           onObscureToggle: () =>
//               setState(() => _obscurePassword = !_obscurePassword),
//           onStudentYearChanged: (v) => setState(() => _studentYear = v),
//           onAcademicLevelChanged: (v) => setState(() => _academicLevel = v),
//           onAddHashtag: _addHashtag,
//           onRemoveHashtag: (tag) => setState(() => _hashtags.remove(tag)),
//         );
//       default:
//         return const SizedBox.shrink();
//     }
//   }
// }

// // ── Step progress bar ─────────────────────────────────────────────────────────
// // 3 equal segments in a Row; segments up to and including currentStep are filled.

// class _StepProgressBar extends StatelessWidget {
//   final int currentStep;
//   final int totalSteps;

//   const _StepProgressBar({
//     required this.currentStep,
//     required this.totalSteps,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//       child: Row(
//         children: List.generate(totalSteps, (i) {
//           final active = i <= currentStep;
//           return Expanded(
//             child: Container(
//               margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
//               height: 4,
//               decoration: BoxDecoration(
//                 // AppColors.accent — #894DEF when active, AppColors.secondary — #EDE9FE otherwise
//                 color: active ? AppColors.accent : AppColors.secondary,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }
// }

// // ── Bottom navigation bar ─────────────────────────────────────────────────────
// // Step 0: Next button full-width (no Back).
// // Steps 1–2: Back (flex 1) + Next/Save (flex 2) side by side.
// // Last step: primary button shows 'Save Session'; shows spinner while submitting.

// class _BottomNav extends StatelessWidget {
//   final int step;
//   final int totalSteps;
//   final bool submitting;
//   final bool canSubmit;
//   final VoidCallback onBack;
//   final VoidCallback onNext;
//   final VoidCallback onSubmit;

//   const _BottomNav({
//     required this.step,
//     required this.totalSteps,
//     required this.submitting,
//     required this.canSubmit,
//     required this.onBack,
//     required this.onNext,
//     required this.onSubmit,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isLast = step == totalSteps - 1;

//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//       decoration: const BoxDecoration(
//         // AppColors.surface — hex unknown (not in app_colors.dart)
//         color: AppColors.surface,
//         border: Border(
//           // AppColors.border — #D4D4D4
//           top: BorderSide(color: AppColors.border),
//         ),
//       ),
//       child: Row(
//         children: [
//           // Back button — hidden on step 0
//           if (step > 0)
//             Expanded(
//               child: OutlinedButton(
//                 style: OutlinedButton.styleFrom(
//                   minimumSize: const Size(double.infinity, 48),
//                 ),
//                 onPressed: submitting ? null : onBack,
//                 child: const Text('Back'),
//               ),
//             ),
//           if (step > 0) const SizedBox(width: 12),
//           // Next / Save button — flex 2
//           Expanded(
//             flex: 2,
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 // AppColors.accent — #894DEF
//                 backgroundColor: AppColors.accent,
//                 minimumSize: const Size(double.infinity, 48),
//               ),
//               onPressed: submitting
//                   ? null
//                   : (isLast ? (canSubmit ? onSubmit : null) : onNext),
//               child: submitting && isLast
//                   ? const SizedBox(
//                       width: 18,
//                       height: 18,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : Text(isLast ? 'Save Session' : 'Next'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Step 1 — Basic info ───────────────────────────────────────────────────────
// // Title (max 80), Description (max 500, 4 lines), Subject grid.
// // NOTE: Subject grid uses old enum; Flutter Engineer must adapt to new schema.

// class _Step1BasicInfo extends StatelessWidget {
//   final TextEditingController titleCtrl;
//   final TextEditingController descCtrl;
//   // [subject / onSubjectChanged — adapt or remove; no Subject enum in new stack]

//   const _Step1BasicInfo({
//     super.key,
//     required this.titleCtrl,
//     required this.descCtrl,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionLabel(label: 'Session Title'),
//           const SizedBox(height: 8),
//           TextField(
//             controller: titleCtrl,
//             maxLength: 80,
//             decoration: const InputDecoration(
//               hintText: 'e.g. Data Structures Study Group',
//               counterText: '',
//             ),
//             textInputAction: TextInputAction.next,
//           ),
//           const SizedBox(height: 20),
//           _SectionLabel(label: 'Description'),
//           const SizedBox(height: 8),
//           TextField(
//             controller: descCtrl,
//             maxLines: 4,
//             maxLength: 500,
//             decoration: const InputDecoration(
//               hintText: 'What will you cover in this session?',
//               alignLabelWithHint: true,
//             ),
//           ),
//           const SizedBox(height: 20),
//           _SectionLabel(label: 'Subject'),
//           const SizedBox(height: 12),
//           // [_SubjectGrid — replace Subject enum chips with academicLevel selector
//           //  or remove this section; hashtag input in Step 3 covers free-text tagging]
//           _SubjectGrid(),
//         ],
//       ),
//     );
//   }
// }

// // Subject chip grid — layout reference only.
// // Old code iterated Subject.values (enum with color + displayName).
// // New stack has no Subject enum; adapt to academicLevel pills or remove.
// class _SubjectGrid extends StatelessWidget {
//   // [selected: Subject, onSelected: ValueChanged<Subject> — adapt types]
//   const _SubjectGrid();

//   @override
//   Widget build(BuildContext context) {
//     // [Wrap of AnimatedContainer chips, one per Subject value]
//     // Active chip: color = s.color at 18% opacity, border = s.color, text = s.color bold
//     // Inactive chip: AppColors.secondary — #EDE9FE bg, Colors.transparent border,
//     //                AppColors.hint — #767676 text normal weight
//     return Wrap(
//       spacing: 10,
//       runSpacing: 10,
//       children: [
//         // [chips generated from Subject.values or replacement list]
//         AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//           decoration: BoxDecoration(
//             // active:   s.color.withValues(alpha: 0.18)
//             // inactive: AppColors.secondary — #EDE9FE
//             color: AppColors.secondary,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//               // active: s.color, width: 1.5
//               // inactive: Colors.transparent
//               color: Colors.transparent,
//               width: 1.5,
//             ),
//           ),
//           child: Text(
//             'Subject Name',
//             style: TextStyle(
//               // active: s.color bold, inactive: AppColors.hint — #767676 normal
//               color: AppColors.hint,
//               fontSize: 13,
//               fontWeight: FontWeight.w400,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Step 2 — Time & location ──────────────────────────────────────────────────
// // Start time tile + end time tile (each opens date → time picker chain).
// // Location text field (max 120).
// // DateTime format: "DD Mon YYYY  HH:mm"

// class _Step2TimeLocation extends StatelessWidget {
//   final DateTime startTime;
//   final DateTime endTime;
//   final TextEditingController locationCtrl;
//   final ValueChanged<DateTime> onStartTimeChanged;
//   final ValueChanged<DateTime> onEndTimeChanged;

//   const _Step2TimeLocation({
//     super.key,
//     required this.startTime,
//     required this.endTime,
//     required this.locationCtrl,
//     required this.onStartTimeChanged,
//     required this.onEndTimeChanged,
//   });

//   // Opens showDatePicker then showTimePicker (chained).
//   // firstDate: DateTime.now() - 1 day; lastDate: DateTime.now() + 365 days.
//   Future<void> _pickDateTime(
//     BuildContext context,
//     DateTime initial,
//     ValueChanged<DateTime> onPicked,
//   ) async {
//     final date = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: DateTime.now().subtract(const Duration(days: 1)),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//     );
//     if (date == null || !context.mounted) return;
//     final time = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.fromDateTime(initial),
//     );
//     if (time == null) return;
//     onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionLabel(label: 'Start Time'),
//           const SizedBox(height: 8),
//           _TimeTile(
//             icon: Icons.calendar_today_outlined,
//             label: _formatDateTime(startTime),
//             onTap: () => _pickDateTime(context, startTime, onStartTimeChanged),
//           ),
//           const SizedBox(height: 16),
//           _SectionLabel(label: 'End Time'),
//           const SizedBox(height: 8),
//           _TimeTile(
//             icon: Icons.access_time_outlined,
//             label: _formatDateTime(endTime),
//             onTap: () => _pickDateTime(context, endTime, onEndTimeChanged),
//           ),
//           const SizedBox(height: 20),
//           _SectionLabel(label: 'Location'),
//           const SizedBox(height: 8),
//           TextField(
//             controller: locationCtrl,
//             maxLength: 120,
//             decoration: const InputDecoration(
//               hintText: 'e.g. LIB Building, Room 301',
//               prefixIcon: Icon(Icons.location_on_outlined, size: 18),
//               counterText: '',
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Format: "5 Jan 2026  14:30"
//   String _formatDateTime(DateTime dt) {
//     const months = [
//       'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
//     ];
//     final hour = dt.hour.toString().padLeft(2, '0');
//     final min = dt.minute.toString().padLeft(2, '0');
//     return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $hour:$min';
//   }
// }

// class _TimeTile extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;

//   const _TimeTile({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//         decoration: BoxDecoration(
//           // AppColors.surface — hex unknown (not in app_colors.dart)
//           color: AppColors.surface,
//           borderRadius: BorderRadius.circular(10),
//           // AppColors.border — #D4D4D4
//           border: Border.all(color: AppColors.border),
//         ),
//         child: Row(
//           children: [
//             Icon(
//               icon,
//               size: 18,
//               // AppColors.accent — #894DEF
//               color: AppColors.accent,
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Text(
//                 label,
//                 style: const TextStyle(
//                   // AppColors.text — #1A1A2E
//                   color: AppColors.text,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             const Icon(
//               Icons.edit_outlined,
//               size: 16,
//               // AppColors.hint — #767676
//               color: AppColors.hint,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Step 3 — Capacity, visibility & filters ───────────────────────────────────

// class _Step3CapacityVisibility extends StatelessWidget {
//   final int capacity;
//   final String visSegment; // 'public' | 'private'
//   final TextEditingController passwordCtrl;
//   final bool obscurePassword;
//   final int? studentYear;
//   final String? academicLevel; // 'undergraduate' | 'graduate' (ADR 0001)
//   final List<String> hashtags;
//   final TextEditingController hashtagCtrl;
//   final bool isEditing;
//   final ValueChanged<int> onCapacityChanged;
//   final ValueChanged<String> onVisSegmentChanged;
//   final VoidCallback onObscureToggle;
//   final ValueChanged<int?> onStudentYearChanged;
//   final ValueChanged<String?> onAcademicLevelChanged;
//   final VoidCallback onAddHashtag;
//   final ValueChanged<String> onRemoveHashtag;

//   const _Step3CapacityVisibility({
//     super.key,
//     required this.capacity,
//     required this.visSegment,
//     required this.passwordCtrl,
//     required this.obscurePassword,
//     required this.studentYear,
//     required this.academicLevel,
//     required this.hashtags,
//     required this.hashtagCtrl,
//     required this.isEditing,
//     required this.onCapacityChanged,
//     required this.onVisSegmentChanged,
//     required this.onObscureToggle,
//     required this.onStudentYearChanged,
//     required this.onAcademicLevelChanged,
//     required this.onAddHashtag,
//     required this.onRemoveHashtag,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isPrivate = visSegment == 'private';

//     return SingleChildScrollView(
//       padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Capacity stepper ────────────────────────────────────────────────
//           _SectionLabel(label: 'Capacity'),
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               // AppColors.surface — hex unknown (not in app_colors.dart)
//               color: AppColors.surface,
//               borderRadius: BorderRadius.circular(10),
//               // AppColors.border — #D4D4D4
//               border: Border.all(color: AppColors.border),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Icon(
//                   Icons.group_outlined,
//                   size: 18,
//                   // AppColors.accent — #894DEF
//                   color: AppColors.accent,
//                 ),
//                 const SizedBox(width: 10),
//                 Text(
//                   '$capacity members',
//                   style: const TextStyle(
//                     // AppColors.text — #1A1A2E
//                     color: AppColors.text,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const Spacer(),
//                 // Minus button — disabled when capacity <= 2
//                 _StepperBtn(
//                   icon: Icons.remove,
//                   onTap: capacity > 2 ? () => onCapacityChanged(capacity - 1) : null,
//                 ),
//                 const SizedBox(width: 8),
//                 // Plus button — disabled when capacity >= 50
//                 _StepperBtn(
//                   icon: Icons.add,
//                   onTap: capacity < 50 ? () => onCapacityChanged(capacity + 1) : null,
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),

//           // ── Visibility segmented button ─────────────────────────────────────
//           _SectionLabel(label: 'Visibility'),
//           const SizedBox(height: 8),
//           SegmentedButton<String>(
//             style: SegmentedButton.styleFrom(
//               // AppColors.secondary — #EDE9FE
//               backgroundColor: AppColors.secondary,
//               // AppColors.accent — #894DEF
//               selectedBackgroundColor: AppColors.accent,
//               selectedForegroundColor: Colors.white,
//               // AppColors.hint — #767676
//               foregroundColor: AppColors.hint,
//               // AppColors.border — #D4D4D4
//               side: const BorderSide(color: AppColors.border),
//             ),
//             segments: const [
//               ButtonSegment(
//                 value: 'public',
//                 label: Text('Public'),
//                 icon: Icon(Icons.public_outlined, size: 16),
//               ),
//               ButtonSegment(
//                 value: 'private',
//                 label: Text('Private'),
//                 icon: Icon(Icons.lock_outline, size: 16),
//               ),
//             ],
//             selected: {visSegment},
//             onSelectionChanged: (s) => onVisSegmentChanged(s.first),
//           ),
//           const SizedBox(height: 8),

//           // Public hint — shown when public is selected
//           if (!isPrivate)
//             const Padding(
//               padding: EdgeInsets.only(bottom: 4),
//               child: Text(
//                 'Joining requires your approval',
//                 style: TextStyle(
//                   // AppColors.hint — #767676
//                   color: AppColors.hint,
//                   fontSize: 12,
//                 ),
//               ),
//             ),

//           // ── PIN field (private only) ────────────────────────────────────────
//           // In edit mode: read-only placeholder '••••••'; password cannot change.
//           // In create mode: obscurable text field with eye toggle.
//           // ADR 0001 pin field stores plaintext, min 4 chars.
//           if (isPrivate) ...[
//             const SizedBox(height: 12),
//             TextField(
//               controller: passwordCtrl,
//               readOnly: isEditing,
//               obscureText: isEditing ? false : obscurePassword,
//               decoration: InputDecoration(
//                 hintText: isEditing ? '••••••' : 'Session password',
//                 helperText: isEditing
//                     ? 'Password cannot be changed after creation.'
//                     : null,
//                 prefixIcon: const Icon(Icons.key_outlined, size: 18),
//                 suffixIcon: isEditing
//                     ? null
//                     : IconButton(
//                         icon: Icon(
//                           obscurePassword
//                               ? Icons.visibility_off_outlined
//                               : Icons.visibility_outlined,
//                           size: 18,
//                           // AppColors.hint — #767676
//                           color: AppColors.hint,
//                         ),
//                         onPressed: onObscureToggle,
//                       ),
//               ),
//             ),
//           ],

//           const SizedBox(height: 20),

//           // ── Optional filters ────────────────────────────────────────────────
//           _SectionLabel(label: 'Filters (optional)'),
//           const SizedBox(height: 12),
//           _AcademicLevelSelector(
//             selected: academicLevel,
//             onChanged: onAcademicLevelChanged,
//           ),
//           const SizedBox(height: 12),
//           _StudentYearSelector(
//             selected: studentYear,
//             academicLevel: academicLevel,
//             onChanged: onStudentYearChanged,
//           ),
//           const SizedBox(height: 20),

//           // ── Hashtags ────────────────────────────────────────────────────────
//           _SectionLabel(label: 'Hashtags (optional)'),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: hashtagCtrl,
//                   maxLength: 30,
//                   decoration: const InputDecoration(
//                     hintText: 'e.g. algorithms',
//                     prefixIcon: Icon(Icons.tag, size: 18),
//                     counterText: '',
//                   ),
//                   onSubmitted: (_) => onAddHashtag(),
//                   // deny whitespace input
//                   inputFormatters: [
//                     FilteringTextInputFormatter.deny(RegExp(r'\s')),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 8),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   minimumSize: const Size(56, 48),
//                 ),
//                 onPressed: onAddHashtag,
//                 child: const Icon(Icons.add, size: 18),
//               ),
//             ],
//           ),
//           if (hashtags.isNotEmpty) ...[
//             const SizedBox(height: 10),
//             Wrap(
//               spacing: 8,
//               runSpacing: 6,
//               children: hashtags
//                   .map((tag) => _HashtagChip(
//                         tag: tag,
//                         onRemove: () => onRemoveHashtag(tag),
//                       ))
//                   .toList(),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// // ── Academic level selector ────────────────────────────────────────────────────
// // "Level:" label + "Any" chip + one chip per AcademicLevel.
// // ADR 0001 values: 'undergraduate' | 'graduate'
// // Old code: AcademicLevel.postgraduate → map to 'graduate'.

// class _AcademicLevelSelector extends StatelessWidget {
//   final String? selected; // 'undergraduate' | 'graduate' | null (= Any)
//   final ValueChanged<String?> onChanged;

//   const _AcademicLevelSelector({
//     required this.selected,
//     required this.onChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         const Text(
//           'Level:',
//           style: TextStyle(
//             // AppColors.hint — #767676
//             color: AppColors.hint,
//             fontSize: 13,
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Wrap(
//             spacing: 8,
//             children: [
//               _FilterChip(
//                 label: 'Any',
//                 selected: selected == null,
//                 onTap: () => onChanged(null),
//               ),
//               _FilterChip(
//                 label: 'Undergraduate',
//                 selected: selected == 'undergraduate',
//                 onTap: () => onChanged(
//                   selected == 'undergraduate' ? null : 'undergraduate',
//                 ),
//               ),
//               _FilterChip(
//                 label: 'Graduate',
//                 selected: selected == 'graduate',
//                 onTap: () => onChanged(
//                   selected == 'graduate' ? null : 'graduate',
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Student year selector ──────────────────────────────────────────────────────
// // "Year:" label + "Any" chip + year chips.
// // Old code: max year = 4 (undergrad) or 2 (postgrad).
// // ADR 0001 allows 1–8. Reconcile max year with team before implementing.

// class _StudentYearSelector extends StatelessWidget {
//   final int? selected;
//   final String? academicLevel; // used to determine max year
//   final ValueChanged<int?> onChanged;

//   const _StudentYearSelector({
//     required this.selected,
//     required this.academicLevel,
//     required this.onChanged,
//   });

//   // Old logic: postgrad → 2, else → 4. ADR 0001 allows 1–8.
//   int get _maxYear => academicLevel == 'graduate' ? 2 : 4;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         const Text(
//           'Year:',
//           style: TextStyle(
//             // AppColors.hint — #767676
//             color: AppColors.hint,
//             fontSize: 13,
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Wrap(
//             spacing: 8,
//             children: [
//               _FilterChip(
//                 label: 'Any',
//                 selected: selected == null,
//                 onTap: () => onChanged(null),
//               ),
//               ...List.generate(_maxYear, (i) {
//                 final year = i + 1;
//                 return _FilterChip(
//                   label: 'Year $year',
//                   selected: selected == year,
//                   onTap: () => onChanged(selected == year ? null : year),
//                 );
//               }),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Small reusable widgets ─────────────────────────────────────────────────────

// class _SectionLabel extends StatelessWidget {
//   final String label;
//   const _SectionLabel({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       label,
//       style: const TextStyle(
//         // AppColors.text — #1A1A2E
//         color: AppColors.text,
//         fontSize: 14,
//         fontWeight: FontWeight.w600,
//       ),
//     );
//   }
// }

// // Animated pill chip — used in AcademicLevel and StudentYear selectors.
// class _FilterChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;

//   const _FilterChip({
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           // AppColors.accent — #894DEF when selected, AppColors.secondary — #EDE9FE otherwise
//           color: selected ? AppColors.accent : AppColors.secondary,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             // Colors.white when selected, AppColors.hint — #767676 otherwise
//             color: selected ? Colors.white : AppColors.hint,
//             fontSize: 12,
//             fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Hashtag chip with '#tag' label and × remove button.
// class _HashtagChip extends StatelessWidget {
//   final String tag;
//   final VoidCallback onRemove;

//   const _HashtagChip({required this.tag, required this.onRemove});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
//       decoration: BoxDecoration(
//         // AppColors.secondary — #EDE9FE
//         color: AppColors.secondary,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             '#$tag',
//             style: const TextStyle(
//               // AppColors.accent — #894DEF
//               color: AppColors.accent,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(width: 4),
//           GestureDetector(
//             onTap: onRemove,
//             child: const Icon(
//               Icons.close,
//               size: 14,
//               // AppColors.hint — #767676
//               color: AppColors.hint,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Capacity ± button. Disabled when onTap is null.
// class _StepperBtn extends StatelessWidget {
//   final IconData icon;
//   final VoidCallback? onTap;

//   const _StepperBtn({required this.icon, this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 32,
//         height: 32,
//         decoration: BoxDecoration(
//           // AppColors.secondary — #EDE9FE when enabled, AppColors.border — #D4D4D4 when disabled
//           color: onTap != null ? AppColors.secondary : AppColors.border,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(
//           icon,
//           size: 16,
//           // AppColors.accent — #894DEF when enabled, AppColors.hint — #767676 when disabled
//           color: onTap != null ? AppColors.accent : AppColors.hint,
//         ),
//       ),
//     );
//   }
// }
