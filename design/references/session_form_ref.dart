// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.
// //
// // Relationship to other references:
// //   create_session_screen_ref.dart → thin wrapper: SessionForm(isEditing: false)
// //   edit_session_screen_ref.dart   → thin wrapper: SessionForm(isEditing: true, initialSession: session,
// //                                    bottomExtra: _DeleteSessionButton)
// //   This file is the authoritative layout reference for the form itself.
// //
// // Schema / field mapping (old → new):
// //   Session model           → SessionEntity  (ADR 0001 + ADR 0003)
// //   s.startTime             → session.scheduledAt      (ADR 0001)
// //   s.endTime               → session.scheduledEndAt   (ADR 0003)
// //   s.hostId                → session.hostUid           (ADR 0001)
// //   me.id                   → me.uid
// //   me.username             → me.displayName
// //   me.profilePhotoUrl      → me.photoUrl
// //   Subject enum            → removed; no ADR 0001 equivalent; _SubjectGrid kept as layout
// //                             reference only — Flutter Engineer must adapt or replace with
// //                             a hashtag/academicLevel picker
// //   AcademicLevel enum      → String?: 'undergraduate' | 'graduate'
// //   AcademicLevel.postgraduate → 'graduate'
// //   SessionVisibility enum  → String: 'public' | 'private'
// //   Timestamp.fromDate()    → Timestamp.fromDate() still needed at data layer; move to
// //                             repository / datasource, not form
// //   FieldValue.delete()     → use FieldValue.delete() at datasource layer only (ADR 0001)
// //   DataException           → domain sealed error class in lib/core/errors/
// //
// // Validation discrepancies vs ADR 0001:
// //   PIN min: old code = 6 chars; ADR 0001 pin min = 4 chars — team to reconcile
// //   capacity min: old code = 2; ADR 0001 capacity ≥ 1 — team to reconcile
// //   capacity max: old code = 50; ADR 0001 has no defined max
// //   _StudentYearSelector _maxYear: old = 4 (undergrad) / 2 (postgrad); ADR 0001 allows 1–8
// //
// // Hashtag note:
// //   _addHashtag() is missing .toLowerCase() — CLAUDE.md requires hashtags lowercase.
// //   New implementation must call .toLowerCase() before adding to _hashtags.
// //
// // Edit path note:
// //   Password cannot change after creation. editSession does not support password re-hashing.
// //   The 'subject' key in the edit updates map has no ADR 0001 equivalent — omit it.

// // ── Session form ───────────────────────────────────────────────────────────────

// class SessionForm extends StatefulWidget {
//   final bool isEditing;
//   // [initialSession: SessionEntity? — required when isEditing is true]
//   final SessionEntity? initialSession;

//   // Slot for an extra widget rendered below the bottom nav bar.
//   // Used by EditSessionScreen to inject the Delete button.
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
//   // ── Step index ────────────────────────────────────────────────────────────────
//   int _step = 0;
//   static const int _totalSteps = 3;

//   // ── Step 1 – Basic info ───────────────────────────────────────────────────────
//   final _titleCtrl = TextEditingController();
//   final _descCtrl = TextEditingController();
//   // [_subject: Subject enum removed — adapt to hashtag or academicLevel picker]

//   // ── Step 2 – Time & location ──────────────────────────────────────────────────
//   DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
//   DateTime _endTime = DateTime.now().add(const Duration(hours: 3));
//   final _locationCtrl = TextEditingController();

//   // ── Step 3 – Capacity, visibility & filters ───────────────────────────────────
//   int _capacity = 5;
//   String _visSegment = 'public'; // 'public' | 'private'
//   final _passwordCtrl = TextEditingController();
//   bool _obscurePassword = true;

//   int? _studentYear;
//   String? _academicLevel; // 'undergraduate' | 'graduate' | null

//   // Hashtags: free-text, lowercase, deduplicated (CLAUDE.md).
//   final _hashtagCtrl = TextEditingController();
//   final List<String> _hashtags = [];

//   // ── Submit state ──────────────────────────────────────────────────────────────
//   bool _submitting = false;

//   bool get _isEditing => widget.isEditing;

//   @override
//   void initState() {
//     super.initState();
//     final s = widget.initialSession;
//     if (s != null) {
//       _titleCtrl.text = s.title;
//       _descCtrl.text = s.description;
//       // [s.subject → no ADR 0001 equivalent; skip or adapt]
//       _startTime = s.scheduledAt;       // old: s.startTime
//       _endTime = s.scheduledEndAt;      // old: s.endTime
//       _locationCtrl.text = s.location;
//       _capacity = s.capacity;
//       _visSegment = s.visibility == 'private' ? 'private' : 'public';
//       _studentYear = s.studentYear;
//       _academicLevel = s.academicLevel; // String? in new schema
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

//   // ── Validation ─────────────────────────────────────────────────────────────────
//   // Rules (keep all — team to reconcile min values with ADR 0001):
//   //   title.trim().isEmpty                    → 'Please enter a session title.'
//   //   location.trim().isEmpty                 → 'Please enter a location.'
//   //   !isEditing && startTime.isBefore(now)   → 'Session start time must be in the future.'
//   //   endTime <= startTime                    → 'End time must be after start time.'
//   //   capacity < 2                            → 'Capacity must be at least 2.'
//   //   private && !isEditing && password.empty → 'Please enter a password for the private session.'
//   //   private && !isEditing && password < 6   → 'Password must be at least 6 characters.'
//   //     (ADR 0001 pin min = 4 — reconcile with team)

//   bool _validate() {
//     if (_titleCtrl.text.trim().isEmpty) {
//       _showError('Please enter a session title.');
//       return false;
//     }
//     if (_locationCtrl.text.trim().isEmpty) {
//       _showError('Please enter a location.');
//       return false;
//     }
//     if (!_isEditing && _startTime.isBefore(DateTime.now())) {
//       _showError('Session start time must be in the future.');
//       return false;
//     }
//     if (_endTime.isBefore(_startTime) ||
//         _endTime.isAtSameMomentAs(_startTime)) {
//       _showError('End time must be after start time.');
//       return false;
//     }
//     if (_capacity < 2) {
//       _showError('Capacity must be at least 2.');
//       return false;
//     }
//     if (_visSegment == 'private' && !_isEditing) {
//       if (_passwordCtrl.text.trim().isEmpty) {
//         _showError('Please enter a password for the private session.');
//         return false;
//       }
//       if (_passwordCtrl.text.trim().length < 6) {
//         _showError('Password must be at least 6 characters.');
//         return false;
//       }
//     }
//     return true;
//   }

//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         // AppColors.error — #CC0000
//         backgroundColor: AppColors.error,
//       ),
//     );
//   }

//   // ── Submit ─────────────────────────────────────────────────────────────────────

//   Future<void> _submit() async {
//     if (!_validate()) return;

//     // [ref.read currentUserProvider → me (UserEntity?); _showError + return if null]
//     setState(() => _submitting = true);
//     try {
//       if (_isEditing) {
//         final s = widget.initialSession!;

//         // Edit path — repository .editSession(sessionId, callerUid, updates)
//         // updates map:
//         //   'title'          : _titleCtrl.text.trim()
//         //   'description'    : _descCtrl.text.trim()
//         //   'location'       : _locationCtrl.text.trim()
//         //   'scheduledAt'    : Timestamp.fromDate(_startTime)   ← at datasource layer
//         //   'scheduledEndAt' : Timestamp.fromDate(_endTime)     ← at datasource layer
//         //   'capacity'       : _capacity
//         //   'visibility'     : _visSegment
//         //   'hashtags'       : _hashtags
//         //   'studentYear'    : _studentYear ?? FieldValue.delete()   ← at datasource layer
//         //   'academicLevel'  : _academicLevel ?? FieldValue.delete() ← at datasource layer
//         // Note: 'subject' key removed — no ADR 0001 equivalent
//         // Note: password change not supported by editSession; immutable after creation
//         //
//         // [fire analytics: session_edited — if you add this event, declare in analytics_events.dart first]
//       } else {
//         // Create path — repository .createSession(entity, plainTextPassword?)
//         // Pass plainTextPassword only when _visSegment == 'private'
//         //
//         // SessionEntity fields to set:
//         //   title, description, hashtags, academicLevel, studentYear
//         //   visibility: _visSegment
//         //   hostUid: me.uid
//         //   hostDisplayName: me.displayName  (denormalized per ADR 0003)
//         //   hostPhotoUrl: me.photoUrl        (nullable, denormalized per ADR 0003)
//         //   scheduledAt: _startTime
//         //   scheduledEndAt: _endTime
//         //   location: _locationCtrl.text.trim()
//         //   capacity: _capacity
//         //   memberUids: [me.uid]             (host is first member)
//         //   status: 'scheduled'
//         //   createdAt / updatedAt: server timestamp via request.time (ADR 0001)
//       }

//       if (mounted) context.pop();
//     } catch (e) {
//       if (mounted) {
//         _showError(e is DataException ? e.message : e.toString());
//       }
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }

//   // ── Step navigation ────────────────────────────────────────────────────────────

//   void _nextStep() {
//     if (_step < _totalSteps - 1) setState(() => _step++);
//   }

//   void _prevStep() {
//     if (_step > 0) setState(() => _step--);
//   }

//   // ── Build ──────────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch currentUserProvider — warm-up so provider is ready on first submit tap]
//     // canSubmit = ref.watch(currentUserProvider).asData?.value != null

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
//           // ── 3-segment step progress bar ────────────────────────────────────
//           _StepProgressBar(currentStep: _step, totalSteps: _totalSteps),

//           // ── Step content — AnimatedSwitcher with FadeTransition ─────────────
//           Expanded(
//             child: AnimatedSwitcher(
//               duration: const Duration(milliseconds: 250),
//               transitionBuilder: (child, animation) =>
//                   FadeTransition(opacity: animation, child: child),
//               child: _buildCurrentStep(),
//             ),
//           ),

//           // ── Bottom navigation (Back + Next/Save) ───────────────────────────
//           _BottomNav(
//             step: _step,
//             totalSteps: _totalSteps,
//             submitting: _submitting,
//             canSubmit: canSubmit, // [ref.watch currentUserProvider != null]
//             onBack: _prevStep,
//             onNext: _nextStep,
//             onSubmit: _submit,
//           ),

//           // ── Optional bottom slot (e.g. Delete button from EditSessionScreen) ─
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
//           // [subject / onSubjectChanged — adapt to new schema]
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

//   void _addHashtag() {
//     // Strip '#', trim, deduplicate.
//     // IMPORTANT: add .toLowerCase() — CLAUDE.md requires hashtags lowercase.
//     final tag = _hashtagCtrl.text.trim().replaceAll('#', '').toLowerCase();
//     if (tag.isNotEmpty && !_hashtags.contains(tag)) {
//       setState(() {
//         _hashtags.add(tag);
//         _hashtagCtrl.clear();
//       });
//     }
//   }
// }

// // ── Step progress bar ──────────────────────────────────────────────────────────
// // Row of 3 equal Expanded segments; segments 0..currentStep are accent, rest secondary.

// class _StepProgressBar extends StatelessWidget {
//   final int currentStep;
//   final int totalSteps;
//   const _StepProgressBar({required this.currentStep, required this.totalSteps});

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
//                 // active: AppColors.accent — #894DEF
//                 // inactive: AppColors.secondary — #EDE9FE
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

// // ── Bottom navigation bar ──────────────────────────────────────────────────────
// // Step 0: Next only (flex 2, full width).
// // Steps 1–2: Back (flex 1) + Next/Save (flex 2), 12px gap.
// // Last step button label: 'Save Session'; disabled if canSubmit is false.
// // Spinner replaces label when submitting on last step.

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
//           top: BorderSide(
//             // AppColors.border — #D4D4D4
//             color: AppColors.border,
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
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

// // ── Step 1 — Basic info ────────────────────────────────────────────────────────
// // Title (maxLength 80) + Description (maxLines 4, maxLength 500) + Subject picker.
// // Subject picker: _SubjectGrid — layout reference only; Flutter Engineer must adapt
// // to hashtag / academicLevel input since Subject enum has no ADR 0001 equivalent.

// class _Step1BasicInfo extends StatelessWidget {
//   final TextEditingController titleCtrl;
//   final TextEditingController descCtrl;
//   // [subject, onSubjectChanged: adapt to new schema]

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
//           const _SectionLabel(label: 'Session Title'),
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
//           const _SectionLabel(label: 'Description'),
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
//           const _SectionLabel(label: 'Subject'),
//           const SizedBox(height: 12),
//           // [_SubjectGrid — layout reference below; adapt to new schema]
//           // _SubjectGrid(selected: subject, onSelected: onSubjectChanged),
//         ],
//       ),
//     );
//   }
// }

// // _SubjectGrid — LAYOUT REFERENCE ONLY.
// // Subject enum removed in new schema. Flutter Engineer must replace with a
// // hashtag chip input or academicLevel selector. Color per subject is gone;
// // use AppColors.accent / AppColors.secondary as a single active/inactive pair.

// class _SubjectGrid extends StatelessWidget {
//   // [selected: adapt to String? or other type]
//   // [onSelected: ValueChanged<...>]
//   const _SubjectGrid({required this.selected, required this.onSelected});

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       spacing: 10,
//       runSpacing: 10,
//       children: [
//         // [Subject.values.map → replace with your subject/hashtag source]
//         // Each chip:
//         GestureDetector(
//           onTap: () {}, // [onSelected(s)]
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 180),
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//             decoration: BoxDecoration(
//               // active: AppColors.accent — #894DEF at 0.18 opacity
//               // inactive: AppColors.secondary — #EDE9FE
//               color: AppColors.secondary,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(
//                 // active: AppColors.accent — #894DEF, width 1.5
//                 // inactive: Colors.transparent
//                 color: Colors.transparent,
//                 width: 1.5,
//               ),
//             ),
//             child: const Text(
//               'Subject label',
//               style: TextStyle(
//                 // active: subject color → use AppColors.accent — #894DEF
//                 // inactive: AppColors.hint — #767676
//                 color: AppColors.hint,
//                 fontSize: 13,
//                 // active: FontWeight.w600 / inactive: FontWeight.w400
//                 fontWeight: FontWeight.w400,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Step 2 — Time & location ───────────────────────────────────────────────────
// // Start Time and End Time: tappable _TimeTile → showDatePicker then showTimePicker.
// // Location: TextField (maxLength 120, prefix location icon).

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
//           const _SectionLabel(label: 'Start Time'),
//           const SizedBox(height: 8),
//           _TimeTile(
//             icon: Icons.calendar_today_outlined,
//             label: _formatDateTime(startTime),
//             onTap: () => _pickDateTime(context, startTime, onStartTimeChanged),
//           ),
//           const SizedBox(height: 16),
//           const _SectionLabel(label: 'End Time'),
//           const SizedBox(height: 8),
//           _TimeTile(
//             icon: Icons.access_time_outlined,
//             label: _formatDateTime(endTime),
//             onTap: () => _pickDateTime(context, endTime, onEndTimeChanged),
//           ),
//           const SizedBox(height: 20),
//           const _SectionLabel(label: 'Location'),
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

//   // Format: "DD Mon YYYY  HH:mm"
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

// // _TimeTile: tappable row — icon + label + trailing edit icon.

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
//           border: Border.all(
//             // AppColors.border — #D4D4D4
//             color: AppColors.border,
//           ),
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

// // ── Step 3 — Capacity, visibility & filters ────────────────────────────────────

// class _Step3CapacityVisibility extends StatelessWidget {
//   final int capacity;
//   final String visSegment;
//   final TextEditingController passwordCtrl;
//   final bool obscurePassword;
//   final int? studentYear;
//   final String? academicLevel; // 'undergraduate' | 'graduate' | null
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
//           // ── Capacity stepper ───────────────────────────────────────────────
//           // min = 2 (old code); max = 50 (old code); ADR 0001 min = 1 — reconcile.
//           const _SectionLabel(label: 'Capacity'),
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               // AppColors.surface — hex unknown (not in app_colors.dart)
//               color: AppColors.surface,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(
//                 // AppColors.border — #D4D4D4
//                 color: AppColors.border,
//               ),
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
//                 _StepperBtn(
//                   icon: Icons.remove,
//                   onTap: capacity > 2
//                       ? () => onCapacityChanged(capacity - 1)
//                       : null,
//                 ),
//                 const SizedBox(width: 8),
//                 _StepperBtn(
//                   icon: Icons.add,
//                   onTap: capacity < 50
//                       ? () => onCapacityChanged(capacity + 1)
//                       : null,
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),

//           // ── Visibility segmented button ────────────────────────────────────
//           const _SectionLabel(label: 'Visibility'),
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

//           // Public hint
//           if (!isPrivate)
//             const Padding(
//               padding: EdgeInsets.only(bottom: 4),
//               child: Text(
//                 'Joining requires your approval',
//                 // AppColors.hint — #767676
//                 style: TextStyle(color: AppColors.hint, fontSize: 12),
//               ),
//             ),

//           // ── Password field (private only) ──────────────────────────────────
//           // Edit mode: readOnly = true, obscureText = false, placeholder '••••••',
//           //   helperText 'Password cannot be changed after creation.'
//           // Create mode: obscureText toggled by visibility icon suffix.
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

//           // ── Optional filters ───────────────────────────────────────────────
//           const _SectionLabel(label: 'Filters (optional)'),
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

//           // ── Hashtags ───────────────────────────────────────────────────────
//           // Input: TextField (maxLength 30) + Add button (56×48).
//           // FilteringTextInputFormatter.deny(RegExp(r'\s')) — no spaces.
//           // onSubmitted also calls onAddHashtag.
//           const _SectionLabel(label: 'Hashtags (optional)'),
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
//                   .map(
//                     (tag) => _HashtagChip(
//                       tag: tag,
//                       onRemove: () => onRemoveHashtag(tag),
//                     ),
//                   )
//                   .toList(),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// // _AcademicLevelSelector: 'Level:' label + 'Any' chip + one chip per level.
// // Old code used AcademicLevel enum with .displayName; new schema uses String.
// // Level values: 'undergraduate' | 'graduate'  (old: postgraduate → 'graduate').

// class _AcademicLevelSelector extends StatelessWidget {
//   final String? selected; // 'undergraduate' | 'graduate' | null
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
//           // AppColors.hint — #767676
//           style: TextStyle(color: AppColors.hint, fontSize: 13),
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
//               // [AcademicLevel.values → 'undergraduate' / 'graduate' strings]
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

// // _StudentYearSelector: 'Year:' label + 'Any' chip + Year 1…_maxYear chips.
// // _maxYear: old code = 4 (undergrad) / 2 (postgrad); ADR 0001 allows 1–8 — reconcile.

// class _StudentYearSelector extends StatelessWidget {
//   final int? selected;
//   final String? academicLevel; // 'undergraduate' | 'graduate' | null
//   final ValueChanged<int?> onChanged;

//   const _StudentYearSelector({
//     required this.selected,
//     required this.academicLevel,
//     required this.onChanged,
//   });

//   // Old logic: undergrad = 4, postgrad = 2. ADR 0001 allows 1–8. Reconcile with team.
//   int get _maxYear => academicLevel == 'graduate' ? 2 : 4;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         const Text(
//           'Year:',
//           // AppColors.hint — #767676
//           style: TextStyle(color: AppColors.hint, fontSize: 13),
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

// // _FilterChip: AnimatedContainer pill.
// // Active: AppColors.accent #894DEF background, white text, w600.
// // Inactive: AppColors.secondary #EDE9FE background, AppColors.hint #767676 text, w400.

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
//           // active: AppColors.accent — #894DEF
//           // inactive: AppColors.secondary — #EDE9FE
//           color: selected ? AppColors.accent : AppColors.secondary,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             // active: Colors.white / inactive: AppColors.hint — #767676
//             color: selected ? Colors.white : AppColors.hint,
//             fontSize: 12,
//             fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // _HashtagChip: '#tag' + × remove button.
// // Padding: fromLTRB(10, 4, 6, 4) — asymmetric right to accommodate close icon.

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

// // _StepperBtn: 32×32 container with icon.
// // Enabled: AppColors.secondary #EDE9FE background, AppColors.accent #894DEF icon.
// // Disabled (onTap == null): AppColors.border #D4D4D4 background, AppColors.hint #767676 icon.

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
//           // enabled: AppColors.secondary — #EDE9FE
//           // disabled: AppColors.border — #D4D4D4
//           color: onTap != null ? AppColors.secondary : AppColors.border,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(
//           icon,
//           size: 16,
//           // enabled: AppColors.accent — #894DEF
//           // disabled: AppColors.hint — #767676
//           color: onTap != null ? AppColors.accent : AppColors.hint,
//         ),
//       ),
//     );
//   }
// }
