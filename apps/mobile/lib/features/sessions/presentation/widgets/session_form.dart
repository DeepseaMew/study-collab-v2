import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Three-step form shared by Create Session and Edit Session screens.
///
/// - Step 0: Basic info (visibility, title, description, subject). PIN shown here when private.
/// - Step 1: Time & location (scheduledAt, scheduledEndAt, location).
/// - Step 2: Capacity, optional filters (academicLevel, studentYear), and hashtags.
///
/// Pass [isEditing] = true and [initialSession] when editing.
/// Use [bottomExtra] to inject an extra widget below the bottom nav bar
/// (e.g., a Delete button from EditSessionScreen).
class SessionForm extends ConsumerStatefulWidget {
  const SessionForm({
    super.key,
    this.isEditing = false,
    this.initialSession,
    this.bottomExtra,
  }) : assert(
         !isEditing || initialSession != null,
         'initialSession is required when isEditing is true',
       );

  final bool isEditing;
  final SessionEntity? initialSession;
  final Widget? bottomExtra;

  @override
  ConsumerState<SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<SessionForm>
    with SingleTickerProviderStateMixin {
  // ── Step index ───────────────────────────────────────────────────────────
  int _step = 0;
  static const int _totalSteps = 3;

  // ── Step 1 — Basic info ──────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _subject;

  // ── Step 2 — Time & location ─────────────────────────────────────────────
  late DateTime _startTime;
  late DateTime _endTime;
  final _locationCtrl = TextEditingController();

  // ── Step 3 — Capacity, visibility & filters ──────────────────────────────
  int _capacity = 5;
  String _visSegment = 'public';
  /// Auto-generated 6-digit numeric PIN for private sessions.
  /// Never shown to the host during creation; stored on submit only.
  String? _autoPin;
  int? _studentYear;
  String? _academicLevel;
  final _hashtagCtrl = TextEditingController();
  final List<String> _hashtags = [];

  // ── Inline validation errors ─────────────────────────────────────────────
  String? _titleError;
  String? _subjectError;
  String? _locationError;

  // ── Submit state ─────────────────────────────────────────────────────────
  bool _submitting = false;

  /// Returns a fresh random 6-digit numeric PIN string.
  static String _generatePin() {
    final rng = Random.secure();
    // Zero-pad to ensure exactly 6 digits.
    return rng.nextInt(900000).toString().padLeft(6, '0');
  }

  bool get _isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_clearTitleError);
    _locationCtrl.addListener(_clearLocationError);
    final now = DateTime.now();
    _startTime = now.add(const Duration(hours: 1));
    _endTime = now.add(const Duration(hours: 3));

    final s = widget.initialSession;
    if (s != null) {
      _titleCtrl.text = s.title;
      _descCtrl.text = s.description ?? '';
      _startTime = s.scheduledAt;
      _endTime = s.scheduledEndAt ?? s.scheduledAt.add(const Duration(hours: 2));
      _locationCtrl.text = s.location;
      _capacity = s.capacity;
      _visSegment = s.visibility == 'private' ? 'private' : 'public';
      _studentYear = s.studentYear;
      _academicLevel = s.academicLevel;
      _hashtags.addAll(s.hashtags);
      _subject = _subjects.cast<String?>().firstWhere(
        (sub) => s.hashtags.contains(sub!.toLowerCase()),
        orElse: () => null,
      );
    }
  }

  void _clearTitleError() {
    if (_titleError != null) setState(() => _titleError = null);
  }

  void _clearSubjectError() {
    if (_subjectError != null) setState(() => _subjectError = null);
  }

  void _clearLocationError() {
    if (_locationError != null) setState(() => _locationError = null);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_clearTitleError);
    _locationCtrl.removeListener(_clearLocationError);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _hashtagCtrl.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Please enter a session title.');
      return false;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      _showError('Please enter a location.');
      return false;
    }
    if (!_isEditing && _startTime.isBefore(DateTime.now())) {
      _showError('Session start time must be in the future.');
      return false;
    }
    if (!_endTime.isAfter(_startTime)) {
      _showError('End time must be after start time.');
      return false;
    }
    // Capacity minimum: 2 (UX reconciliation; ADR 0001 allows >= 1).
    if (_capacity < 2) {
      _showError('Capacity must be at least 2.');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;

    final me = ref.read(currentUserProvider).asData?.value;
    if (me == null) {
      _showError('You must be signed in.');
      return;
    }

    setState(() => _submitting = true);

    // Merge selected subject (lowercase) as first hashtag, avoid duplicates.
    final subjectTag = _subject?.toLowerCase();
    final allHashtags = [
      if (subjectTag != null && !_hashtags.contains(subjectTag)) subjectTag,
      ..._hashtags,
    ];

    try {
      final repo = ref.read(sessionRepositoryProvider);

      if (_isEditing) {
        final s = widget.initialSession!;
        final updates = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'scheduledAt': _startTime,
          'scheduledEndAt': _endTime,
          'capacity': _capacity,
          'visibility': _visSegment,
          'hashtags': allHashtags,
        };
        if (_studentYear != null) {
          updates['studentYear'] = _studentYear;
        }
        if (_academicLevel != null) {
          updates['academicLevel'] = _academicLevel;
        }
        await repo.editSession(s.sessionId, me.uid, updates);
        appLogger.info(
          'Session edited',
          extra: {'sessionId': s.sessionId},
        );
        // Analytics: declared in analytics_events.dart
        appLogger.debug(AnalyticsEvents.sessionEdited);
      } else {
        final entity = SessionEntity(
          sessionId: '',
          hostUid: me.uid,
          hostFaculty: me.faculty,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          hashtags: allHashtags,
          academicLevel: _academicLevel ?? 'undergraduate',
          studentYear: _studentYear ?? 1,
          visibility: _visSegment,
          memberUids: const [],
          noteCount: 0,
          status: 'scheduled',
          scheduledAt: _startTime,
          scheduledEndAt: _endTime,
          location: _locationCtrl.text.trim(),
          capacity: _capacity,
          hostDisplayName: me.displayName,
          hostPhotoUrl: me.photoUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createSession(
          entity,
          plainTextPin: _visSegment == 'private' ? _autoPin : null,
        );
        appLogger.info('Session created via form');
        appLogger.debug(AnalyticsEvents.sessionCreated);
      }

      if (mounted) context.pop();
    } catch (e, st) {
      appLogger.error(
        'Session form submit failed',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step navigation ───────────────────────────────────────────────────────
  void _nextStep() {
    if (_step == 0) {
      final titleErr = _titleCtrl.text.trim().isEmpty
          ? 'Session title is required'
          : null;
      final subjectErr = _subject == null ? 'Please select a subject' : null;
      if (titleErr != null || subjectErr != null) {
        setState(() {
          _titleError = titleErr;
          _subjectError = subjectErr;
        });
        return;
      }
    }
    if (_step == 1 && _locationCtrl.text.trim().isEmpty) {
      setState(() => _locationError = 'Location is required');
      return;
    }
    if (_step < _totalSteps - 1) setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  void _addHashtag() {
    // Strip '#', trim, lowercase, deduplicate — required by CLAUDE.md.
    final tag =
        _hashtagCtrl.text.trim().replaceAll('#', '').toLowerCase();
    if (tag.isNotEmpty && !_hashtags.contains(tag) && _hashtags.length < 20) {
      setState(() {
        _hashtags.add(tag);
        _hashtagCtrl.clear();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Warm-up currentUserProvider so canSubmit is ready on first build.
    final me = ref.watch(currentUserProvider).asData?.value;
    final canSubmit = me != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Session' : 'Create Session',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _StepProgressBar(currentStep: _step, totalSteps: _totalSteps),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _buildCurrentStep(),
            ),
          ),
          _BottomNav(
            step: _step,
            totalSteps: _totalSteps,
            submitting: _submitting,
            canSubmit: canSubmit,
            onBack: _prevStep,
            onNext: _nextStep,
            onSubmit: _submit,
          ),
          if (widget.bottomExtra != null) widget.bottomExtra!,
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step1BasicInfo(
          key: const ValueKey('step0'),
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          titleError: _titleError,
          visSegment: _visSegment,
          onVisSegmentChanged: (v) {
            setState(() {
              _visSegment = v;
              // Auto-generate a PIN the first time the host picks private,
              // and regenerate on every subsequent toggle to private so that
              // discarding and restarting always gives a fresh PIN.
              if (v == 'private' && !_isEditing) {
                _autoPin = _generatePin();
                appLogger.debug('Auto-generated PIN for private session');
              } else if (v == 'public') {
                _autoPin = null;
              }
            });
          },
          subject: _subject,
          onSubjectChanged: (v) {
            setState(() => _subject = v);
            _clearSubjectError();
          },
          subjectError: _subjectError,
          isEditing: _isEditing,
        );
      case 1:
        return _Step2TimeLocation(
          key: const ValueKey('step1'),
          startTime: _startTime,
          endTime: _endTime,
          locationCtrl: _locationCtrl,
          locationError: _locationError,
          onStartTimeChanged: (dt) => setState(() => _startTime = dt),
          onEndTimeChanged: (dt) => setState(() => _endTime = dt),
        );
      case 2:
        return _Step3CapacityVisibility(
          key: const ValueKey('step2'),
          capacity: _capacity,
          studentYear: _studentYear,
          academicLevel: _academicLevel,
          hashtags: _hashtags,
          hashtagCtrl: _hashtagCtrl,
          onCapacityChanged: (v) => setState(() => _capacity = v),
          onStudentYearChanged: (v) => setState(() => _studentYear = v),
          onAcademicLevelChanged: (v) => setState(() => _academicLevel = v),
          onAddHashtag: _addHashtag,
          onRemoveHashtag: (tag) => setState(() => _hashtags.remove(tag)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i <= currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.accent : AppColors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.step,
    required this.totalSteps,
    required this.submitting,
    required this.canSubmit,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final int step;
  final int totalSteps;
  final bool submitting;
  final bool canSubmit;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: submitting ? null : onBack,
                child: const Text('Back'),
              ),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: submitting
                  ? null
                  : (isLast ? (canSubmit ? onSubmit : null) : onNext),
              child: submitting && isLast
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isLast ? 'Save Session' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1 — Basic info ───────────────────────────────────────────────────────

class _Step1BasicInfo extends StatelessWidget {
  const _Step1BasicInfo({
    super.key,
    required this.titleCtrl,
    required this.descCtrl,
    required this.visSegment,
    required this.onVisSegmentChanged,
    required this.onSubjectChanged,
    required this.isEditing,
    this.titleError,
    this.subject,
    this.subjectError,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String visSegment;
  final ValueChanged<String> onVisSegmentChanged;
  final String? subject;
  final ValueChanged<String?> onSubjectChanged;
  final String? titleError;
  final String? subjectError;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Visibility ────────────────────────────────────────────────
          const _SectionLabel(label: 'Visibility'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              selectedBackgroundColor: AppColors.accent,
              selectedForegroundColor: Colors.white,
              foregroundColor: AppColors.hint,
              side: const BorderSide(color: AppColors.border),
            ),
            segments: const [
              ButtonSegment(
                value: 'public',
                label: Text('Public'),
                icon: Icon(Icons.public_outlined, size: 16),
              ),
              ButtonSegment(
                value: 'private',
                label: Text('Private'),
                icon: Icon(Icons.lock_outline, size: 16),
              ),
            ],
            selected: {visSegment},
            onSelectionChanged: (s) => onVisSegmentChanged(s.first),
          ),
          if (visSegment == 'public') ...[
            const SizedBox(height: 4),
            const Text(
              'Joining requires your approval',
              style: TextStyle(color: AppColors.hint, fontSize: 12),
            ),
          ],
          if (visSegment == 'private') ...[
            const SizedBox(height: 4),
            const Text(
              'A secure PIN will be generated automatically. '
              'You can share it with members from the session details page.',
              style: TextStyle(color: AppColors.hint, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),

          // ── Session Title ─────────────────────────────────────────────
          const _SectionLabel(label: 'Session Title'),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtrl,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: 'e.g. Data Structures Study Group',
              counterText: '',
              errorText: titleError,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────────
          const _SectionLabel(label: 'Description'),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'What will you cover in this session?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // ── Subject (required) ────────────────────────────────────────
          const Row(
            children: [
              _SectionLabel(label: 'Subject'),
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SubjectChipGrid(
            selected: subject,
            onSelected: onSubjectChanged,
          ),
          if (subjectError != null) ...[
            const SizedBox(height: 6),
            Text(
              subjectError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Subject chip grid ─────────────────────────────────────────────────────────

const List<String> _subjects = [
  'Mathematics',
  'Computer Science',
  'Chemistry',
  'Physics',
  'Biology',
  'Economics',
  'English',
];

class _SubjectChipGrid extends StatelessWidget {
  const _SubjectChipGrid({
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _subjects.map((subject) {
        final isActive = subject == selected;
        return Semantics(
          label: subject,
          selected: isActive,
          button: true,
          child: GestureDetector(
          onTap: () => onSelected(isActive ? null : subject),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              subject,
              style: TextStyle(
                color: isActive ? AppColors.accent : AppColors.hint,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Step 2 — Time & location ──────────────────────────────────────────────────

class _Step2TimeLocation extends StatelessWidget {
  const _Step2TimeLocation({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.locationCtrl,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    this.locationError,
  });

  final DateTime startTime;
  final DateTime endTime;
  final TextEditingController locationCtrl;
  final ValueChanged<DateTime> onStartTimeChanged;
  final ValueChanged<DateTime> onEndTimeChanged;
  final String? locationError;

  Future<void> _pickDateTime(
    BuildContext context,
    DateTime initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (time == null) return;
    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Start Time'),
          const SizedBox(height: 8),
          _TimeTile(
            icon: Icons.calendar_today_outlined,
            label: DateFormatter.formatDateTime(startTime),
            onTap: () => _pickDateTime(context, startTime, onStartTimeChanged),
          ),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'End Time'),
          const SizedBox(height: 8),
          _TimeTile(
            icon: Icons.access_time_outlined,
            label: DateFormatter.formatDateTime(endTime),
            onTap: () => _pickDateTime(context, endTime, onEndTimeChanged),
          ),
          const SizedBox(height: 20),
          const _SectionLabel(label: 'Location'),
          const SizedBox(height: 8),
          TextField(
            controller: locationCtrl,
            maxLength: 120,
            decoration: InputDecoration(
              hintText: 'e.g. CB2308',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
              counterText: '',
              errorText: locationError,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3 — Capacity, visibility & filters ───────────────────────────────────

class _Step3CapacityVisibility extends StatelessWidget {
  const _Step3CapacityVisibility({
    super.key,
    required this.capacity,
    required this.studentYear,
    required this.academicLevel,
    required this.hashtags,
    required this.hashtagCtrl,
    required this.onCapacityChanged,
    required this.onStudentYearChanged,
    required this.onAcademicLevelChanged,
    required this.onAddHashtag,
    required this.onRemoveHashtag,
  });

  final int capacity;
  final int? studentYear;
  final String? academicLevel;
  final List<String> hashtags;
  final TextEditingController hashtagCtrl;
  final ValueChanged<int> onCapacityChanged;
  final ValueChanged<int?> onStudentYearChanged;
  final ValueChanged<String?> onAcademicLevelChanged;
  final VoidCallback onAddHashtag;
  final ValueChanged<String> onRemoveHashtag;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Capacity stepper ─────────────────────────────────────────────
          const _SectionLabel(label: 'Capacity'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Text(
                  '$capacity members',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _StepperBtn(
                  icon: Icons.remove,
                  onTap: capacity > 2
                      ? () => onCapacityChanged(capacity - 1)
                      : null,
                ),
                const SizedBox(width: 8),
                _StepperBtn(
                  icon: Icons.add,
                  onTap: capacity < 50
                      ? () => onCapacityChanged(capacity + 1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Optional filters ─────────────────────────────────────────────
          const _SectionLabel(label: 'Filters (optional)'),
          const SizedBox(height: 12),
          _AcademicLevelSelector(
            selected: academicLevel,
            onChanged: onAcademicLevelChanged,
          ),
          const SizedBox(height: 12),
          _StudentYearSelector(
            selected: studentYear,
            academicLevel: academicLevel,
            onChanged: onStudentYearChanged,
          ),
          const SizedBox(height: 20),

          // ── Hashtags ─────────────────────────────────────────────────────
          const _SectionLabel(label: 'Hashtags (optional)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hashtagCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    hintText: 'e.g. algorithms',
                    prefixIcon: Icon(Icons.tag, size: 18),
                    counterText: '',
                  ),
                  onSubmitted: (_) => onAddHashtag(),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(56, 48),
                ),
                onPressed: onAddHashtag,
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          if (hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: hashtags
                  .map(
                    (tag) => _HashtagChip(
                      tag: tag,
                      onRemove: () => onRemoveHashtag(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Academic level selector ───────────────────────────────────────────────────

class _AcademicLevelSelector extends StatelessWidget {
  const _AcademicLevelSelector({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Level:',
          style: TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
              _FilterChip(
                label: 'Undergraduate',
                selected: selected == 'undergraduate',
                onTap: () => onChanged(
                  selected == 'undergraduate' ? null : 'undergraduate',
                ),
              ),
              _FilterChip(
                label: 'Graduate',
                selected: selected == 'graduate',
                onTap: () => onChanged(
                  selected == 'graduate' ? null : 'graduate',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Student year selector ─────────────────────────────────────────────────────

class _StudentYearSelector extends StatelessWidget {
  const _StudentYearSelector({
    required this.selected,
    required this.academicLevel,
    required this.onChanged,
  });

  final int? selected;
  final String? academicLevel;
  final ValueChanged<int?> onChanged;

  // Old code: undergrad = 4, postgrad = 2. ADR 0001 allows 1–8. Using old code.
  int get _maxYear => academicLevel == 'graduate' ? 2 : 4;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Year:',
          style: TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
              ...List.generate(_maxYear, (i) {
                final year = i + 1;
                return _FilterChip(
                  label: 'Year $year',
                  selected: selected == year,
                  onTap: () => onChanged(selected == year ? null : year),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small reusable form widgets ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.secondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.hint,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag, required this.onRemove});

  final String tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.secondary : AppColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.accent : AppColors.hint,
        ),
      ),
    );
  }
}
