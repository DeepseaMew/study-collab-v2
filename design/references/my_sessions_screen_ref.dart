// // DESIGN REFERENCE ONLY — do not run, do not import.
// // Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// // Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// // Follow CLAUDE.md conventions.

// // ── Screen ─────────────────────────────────────────────────────────────────────

// class MySessionsScreen extends StatefulWidget {
//   const MySessionsScreen({super.key});

//   @override
//   State<MySessionsScreen> createState() => _MySessionsScreenState();
// }

// class _MySessionsScreenState extends State<MySessionsScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController; // TabController(length: 3, vsync: this)

//   // [_subjectFilter: String? — active hashtag filter; null = no filter.
//   //  In new schema, sessions have List<String> hashtags; filter by hashtags.contains(value).
//   //  Old codebase used a Subject enum here — replace with String? in new stack.]
//   String? _hashtagFilter;

//   DateTimeRange? _dateRange;
//   String? _dateRangeLabel;

//   // Tab indicator / active-label color — intentionally NOT AppColors.accent.
//   // Color(0xFF5186CD)
//   static const _indicatorColor = Color(0xFF5186CD);

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _tabController.addListener(() => setState(() {}));
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   void _openSearch() {
//     // [showModalBottomSheet → SearchBottomSheet (search by session name)]
//   }

//   Future<void> _pickDateRange() async {
//     final range = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now().add(const Duration(days: 730)),
//       initialDateRange: _dateRange,
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: Theme.of(ctx).colorScheme.copyWith(
//             // AppColors.accent — #894DEF
//             primary: AppColors.accent,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (range != null) {
//       setState(() {
//         _dateRange = range;
//         // label format: "M/D – M/D"
//         String fmt(DateTime d) => '${d.month}/${d.day}';
//         _dateRangeLabel = '${fmt(range.start)} – ${fmt(range.end)}';
//       });
//     }
//   }

//   // [_applyFilters: client-side filter on a List<Session>
//   //   if _hashtagFilter != null → keep sessions where hashtags.contains(_hashtagFilter)
//   //   if _dateRange != null     → keep sessions where scheduledAt is within the range]

//   @override
//   Widget build(BuildContext context) {
//     // [ref.watch currentUserProvider → me (User?)]
//     // When me == null: show empty Scaffold shell with 0 counts + CircularProgressIndicator

//     // [ref.watch upcomingSessionsProvider(me.id) → AsyncValue<List<SessionEntity>>]
//     // [ref.watch completedSessionsProvider(me.id) → AsyncValue<List<SessionEntity>>]
//     // [ref.watch hostedSessionsProvider(me.id)    → AsyncValue<List<SessionEntity>>]

//     // Apply _applyFilters client-side to each list before computing counts.
//     // upcoming, completed, mine are the filtered lists.

//     // Build hashtag list: unique hashtags across all three streams, sorted alphabetically.
//     // Used to populate the filter chips in _FilterRow.

//     return Scaffold(
//       // AppColors.background — #FFFFFF
//       backgroundColor: AppColors.background,
//       appBar: _buildAppBar(
//         upcomingCount: upcoming.length,
//         completedCount: completed.length,
//         mineCount: mine.length,
//         hashtags: hashtags, // [unique sorted hashtags across all sessions]
//       ),
//       body: Column(
//         children: [
//           _FilterRow(
//             hashtags: hashtags,
//             activeHashtag: _hashtagFilter,
//             dateRangeLabel: _dateRangeLabel,
//             onHashtagTap: (h) => setState(
//               () => _hashtagFilter = _hashtagFilter == h ? null : h,
//             ),
//             onDateRangeTap: _pickDateRange,
//             onClearDate: () => setState(() {
//               _dateRange = null;
//               _dateRangeLabel = null;
//             }),
//           ),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _tabContent(
//                   sessions: upcoming,
//                   isLoading: upcomingAsync.isLoading,
//                   hasError: upcomingAsync.hasError,
//                   emptyIcon: Icons.upcoming_outlined,
//                   emptyTitle: 'No upcoming sessions',
//                   emptyBody: 'Sessions you join will appear here',
//                   onCardTap: (s) {}, // [context.push('/my-sessions/session/{id}/member')]
//                 ),
//                 _tabContent(
//                   sessions: completed,
//                   isLoading: completedAsync.isLoading,
//                   hasError: completedAsync.hasError,
//                   emptyIcon: Icons.check_circle_outline,
//                   emptyTitle: 'No completed sessions yet',
//                   emptyBody: 'Completed sessions will show up here',
//                   onCardTap: (s) {}, // [context.push('/my-sessions/session/{id}/member')]
//                 ),
//                 _tabContent(
//                   sessions: mine,
//                   isLoading: hostedAsync.isLoading,
//                   hasError: hostedAsync.hasError,
//                   emptyIcon: Icons.add_circle_outline,
//                   emptyTitle: 'No sessions created',
//                   emptyBody: 'Tap + to create your first session!',
//                   onCardTap: (s) {}, // [context.push('/my-sessions/session/{id}/host')]
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Renders loading / error / data state for a single tab.
//   Widget _tabContent({
//     required List<SessionEntity> sessions,
//     required bool isLoading,
//     required bool hasError,
//     required IconData emptyIcon,
//     required String emptyTitle,
//     required String emptyBody,
//     void Function(SessionEntity)? onCardTap,
//   }) {
//     if (isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (hasError) {
//       return Center(
//         child: Text(
//           'Could not load sessions. Please try again.',
//           // AppColors.error — #CC0000
//           style: const TextStyle(color: AppColors.error),
//           textAlign: TextAlign.center,
//         ),
//       );
//     }
//     return _SessionList(
//       sessions: sessions,
//       emptyIcon: emptyIcon,
//       emptyTitle: emptyTitle,
//       emptyBody: emptyBody,
//       onCardTap: onCardTap,
//     );
//   }

//   // AppBar with TabBar that shows live counts in tab labels.
//   PreferredSizeWidget _buildAppBar({
//     required int upcomingCount,
//     required int completedCount,
//     required int mineCount,
//     required List<String> hashtags,
//   }) {
//     return AppBar(
//       automaticallyImplyLeading: false,
//       titleSpacing: 20,
//       title: const Text('My Sessions'),
//       actions: [
//         IconButton(
//           icon: const Icon(Icons.search_outlined),
//           onPressed: _openSearch,
//         ),
//       ],
//       bottom: TabBar(
//         controller: _tabController,
//         // Color(0xFF5186CD) — hardcoded tab indicator, not AppColors.accent
//         indicatorColor: _indicatorColor,
//         // Color(0xFF5186CD)
//         labelColor: _indicatorColor,
//         // AppColors.hint — #767676
//         unselectedLabelColor: AppColors.hint,
//         labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
//         unselectedLabelStyle: const TextStyle(
//           fontSize: 12,
//           fontWeight: FontWeight.w400,
//         ),
//         tabs: [
//           Tab(text: 'Upcoming ($upcomingCount)'),
//           Tab(text: 'Completed ($completedCount)'),
//           Tab(text: 'Mine ($mineCount)'),
//         ],
//       ),
//     );
//   }
// }

// // ── Filter row ─────────────────────────────────────────────────────────────────
// // Horizontally scrollable row: date-range chip first, then one chip per hashtag.
// // In the old codebase this used a Subject enum; new stack uses String hashtags.

// class _FilterRow extends StatelessWidget {
//   final List<String> hashtags;
//   final String? activeHashtag;
//   final String? dateRangeLabel;
//   final ValueChanged<String> onHashtagTap;
//   final VoidCallback onDateRangeTap;
//   final VoidCallback onClearDate;

//   const _FilterRow({
//     required this.hashtags,
//     required this.activeHashtag,
//     required this.dateRangeLabel,
//     required this.onHashtagTap,
//     required this.onDateRangeTap,
//     required this.onClearDate,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       // AppColors.surface — hex unknown (not in app_colors.dart)
//       color: AppColors.surface,
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         child: Row(
//           children: [
//             // Date range chip — active when dateRangeLabel != null
//             FilterChip(
//               avatar: const Icon(Icons.date_range_outlined, size: 15),
//               label: Text(dateRangeLabel ?? 'Date Range'),
//               selected: dateRangeLabel != null,
//               onSelected: (_) => onDateRangeTap(),
//               // AppColors.secondary — #EDE9FE
//               selectedColor: AppColors.secondary,
//               // AppColors.accent — #894DEF
//               checkmarkColor: AppColors.accent,
//               deleteIcon: dateRangeLabel != null
//                   ? const Icon(Icons.close, size: 14)
//                   : null,
//               onDeleted: dateRangeLabel != null ? onClearDate : null,
//               labelStyle: TextStyle(
//                 fontSize: 12,
//                 // AppColors.accent — #894DEF when active, AppColors.hint — #767676 otherwise
//                 color: dateRangeLabel != null ? AppColors.accent : AppColors.hint,
//               ),
//               side: BorderSide(
//                 // AppColors.accent — #894DEF when active, AppColors.border — #D4D4D4 otherwise
//                 color: dateRangeLabel != null ? AppColors.accent : AppColors.border,
//               ),
//               // AppColors.surface — hex unknown
//               backgroundColor: AppColors.surface,
//               visualDensity: VisualDensity.compact,
//             ),
//             const SizedBox(width: 8),
//             // One chip per hashtag — active when hashtag == activeHashtag
//             ...hashtags.map((h) {
//               final active = h == activeHashtag;
//               return Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: FilterChip(
//                   label: Text(h),
//                   selected: active,
//                   onSelected: (_) => onHashtagTap(h),
//                   // AppColors.secondary — #EDE9FE
//                   selectedColor: AppColors.secondary,
//                   // AppColors.accent — #894DEF
//                   checkmarkColor: AppColors.accent,
//                   labelStyle: TextStyle(
//                     fontSize: 12,
//                     // AppColors.accent — #894DEF when active, AppColors.hint — #767676 otherwise
//                     color: active ? AppColors.accent : AppColors.hint,
//                   ),
//                   side: BorderSide(
//                     // AppColors.accent — #894DEF when active, AppColors.border — #D4D4D4 otherwise
//                     color: active ? AppColors.accent : AppColors.border,
//                   ),
//                   // AppColors.surface — hex unknown
//                   backgroundColor: AppColors.surface,
//                   visualDensity: VisualDensity.compact,
//                 ),
//               );
//             }),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Session list ───────────────────────────────────────────────────────────────

// class _SessionList extends StatelessWidget {
//   final List<SessionEntity> sessions;
//   final IconData emptyIcon;
//   final String emptyTitle;
//   final String emptyBody;
//   final void Function(SessionEntity)? onCardTap;

//   const _SessionList({
//     required this.sessions,
//     required this.emptyIcon,
//     required this.emptyTitle,
//     required this.emptyBody,
//     this.onCardTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final tt = Theme.of(context).textTheme;

//     if (sessions.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Icon in a circular container
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 // AppColors.secondary — #EDE9FE
//                 color: AppColors.secondary,
//                 borderRadius: BorderRadius.circular(40),
//               ),
//               child: Icon(
//                 emptyIcon,
//                 size: 36,
//                 // AppColors.accent — #894DEF
//                 color: AppColors.accent,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               emptyTitle,
//               // tt.displaySmall + AppColors.text — #1A1A2E
//               style: tt.displaySmall?.copyWith(color: AppColors.text),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               emptyBody,
//               // tt.bodyMedium + AppColors.hint — #767676
//               style: tt.bodyMedium?.copyWith(color: AppColors.hint),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//       itemCount: sessions.length,
//       itemBuilder: (ctx, i) {
//         final session = sessions[i];
//         // [SessionCard — lib/features/my_sessions/presentation/widgets/session_card.dart]
//         // Wrap with GestureDetector + AbsorbPointer when onCardTap is provided.
//         if (onCardTap != null) {
//           return GestureDetector(
//             onTap: () => onCardTap!(session),
//             child: AbsorbPointer(
//               // [SessionCard(session: session)]
//               child: const Placeholder(fallbackHeight: 80),
//             ),
//           );
//         }
//         // [SessionCard(session: session)]
//         return const Placeholder(fallbackHeight: 80);
//       },
//     );
//   }
// }
