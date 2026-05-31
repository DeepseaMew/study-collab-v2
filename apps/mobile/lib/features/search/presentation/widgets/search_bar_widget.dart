import 'package:flutter/material.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Standalone search bar with purple border, leading search icon, and a
/// circular clear button visible only when text is non-empty.
///
/// Wrap with [Semantics] label "Search sessions" for accessibility.
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  static const _kPurple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search sessions',
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search sessions, #hashtags...',
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _kPurple, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) {
              if (controller.text.isEmpty) return const SizedBox.shrink();
              return Semantics(
                label: 'Clear search text',
                button: true,
                child: IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    size: 18,
                    color: AppColors.hint,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
              );
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPurple, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPurple, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPurple, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: AppColors.white,
          isDense: true,
        ),
      ),
    );
  }
}
