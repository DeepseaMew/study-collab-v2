import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/domain/entities/academic_level.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Modal bottom sheet for editing the current user's profile.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.user});

  final UserEntity user;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _facultyCtrl;
  late final TextEditingController _bioCtrl;
  late int _studentYear;
  late AcademicLevel _academicLevel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _facultyCtrl = TextEditingController(text: widget.user.faculty);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _studentYear = widget.user.studentYear;
    _academicLevel = AcademicLevel.fromString(widget.user.academicLevel);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _facultyCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onLevelChanged(AcademicLevel? level) {
    if (level == null) return;
    setState(() {
      _academicLevel = level;
      if (_studentYear > _academicLevel.maxYear) {
        _studentYear = _academicLevel.maxYear;
      }
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(firebaseAuthStateProvider).valueOrNull?.uid;
      if (uid == null) {
        appLogger.warning('EditProfileSheet._save called with null uid');
        return;
      }
      await ref.read(userRepositoryProvider).updateProfile(uid, {
        'displayName': _nameCtrl.text.trim(),
        'faculty': _facultyCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'studentYear': _studentYear,
        'academicLevel': _academicLevel.name,
      });
      appLogger.info(AnalyticsEvents.profileEdited);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      appLogger.error(
        'EditProfileSheet._save failed',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final maxYear = _academicLevel.maxYear;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Edit Profile', style: tt.displaySmall),
                const SizedBox(height: 20),
                _Field(label: 'Name', ctrl: _nameCtrl, hint: 'Your name'),
                const SizedBox(height: 14),
                _Field(
                  label: 'Faculty',
                  ctrl: _facultyCtrl,
                  hint: 'e.g. Engineering',
                ),
                const SizedBox(height: 14),
                Text(
                  'Academic Level',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButton<AcademicLevel>(
                  value: _academicLevel,
                  isExpanded: true,
                  items: AcademicLevel.values
                      .map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(level.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: _onLevelChanged,
                ),
                const SizedBox(height: 14),
                Text(
                  'Year',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: _studentYear,
                  isExpanded: true,
                  items: List.generate(maxYear, (i) => i + 1)
                      .map(
                        (y) =>
                            DropdownMenuItem(value: y, child: Text('Year $y')),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) setState(() => _studentYear = v);
                        },
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Bio',
                  ctrl: _bioCtrl,
                  hint: 'Tell others about yourself...',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
