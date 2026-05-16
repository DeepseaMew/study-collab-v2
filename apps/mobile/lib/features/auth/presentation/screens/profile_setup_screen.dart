import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/enums/kmutt_faculty.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  KmuttFaculty? _selectedFaculty;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Pre-fill displayName and bio from Firestore via userProfileProvider.
      // ProviderScope is available by this point because the widget tree has
      // been fully mounted; ref.read is safe here.
      final profileAsync = ref.read(userProfileProvider);
      profileAsync.whenData((profile) {
        final name = (profile['displayName'] as String?) ?? '';
        final bio = (profile['bio'] as String?) ?? '';
        if (name.isNotEmpty) {
          _displayNameController.text = name;
        }
        if (bio.isNotEmpty) {
          _bioController.text = bio;
        }
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFaculty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your faculty')),
      );
      return;
    }

    await ref
        .read(authStateNotifierProvider.notifier)
        .updateProfile(
          displayName: _displayNameController.text.trim(),
          faculty: _selectedFaculty!.name,
          bio: _bioController.text.trim(),
        );
  }

  String _mapFailure(AuthFailure failure) => switch (failure) {
    NetworkFailure() => 'Network error. Check your connection.',
    UnknownFailure(:final message) =>
      message ?? 'Something went wrong. Please try again.',
    _ => 'Something went wrong. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateNotifierProvider);
    final isLoading = authAsync.isLoading;
    final failure = authAsync.hasError ? authAsync.error as AuthFailure? : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Set up your profile',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: AppColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Almost there! Tell us a bit about yourself.',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.hint,
                  ),
                ),
                const SizedBox(height: 24),
                if (failure != null) ...[
                  _ErrorBanner(message: _mapFailure(failure)),
                  const SizedBox(height: 16),
                ],
                const _FieldLabel(label: 'Display name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _displayNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(hint: 'How others will see you'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Display name is required';
                    }
                    if (v.trim().length > 100) {
                      return 'Max 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Faculty'),
                const SizedBox(height: 6),
                DropdownButtonFormField<KmuttFaculty>(
                  initialValue: _selectedFaculty,
                  decoration: _inputDecoration(hint: 'Select your faculty'),
                  isExpanded: true,
                  items: KmuttFaculty.values
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f.label,
                            style: AppTypography.textTheme.bodyMedium?.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFaculty = v),
                  validator: (v) =>
                      v == null ? 'Please select your faculty' : null,
                ),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Bio (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 300,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    hint: 'Tell others about yourself…',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isLoading ? null : _handleSave,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            'Save and continue',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
      color: AppColors.hint,
    ),
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.textTheme.labelLarge?.copyWith(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
