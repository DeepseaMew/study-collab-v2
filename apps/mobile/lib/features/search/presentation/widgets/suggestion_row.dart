import 'package:flutter/material.dart';
import 'package:mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// A single row inside the search suggestions overlay.
///
/// Displays a leading icon based on [suggestion.type], the suggestion text
/// with the typed [query] prefix rendered in normal weight and the completion
/// in bold, and a trailing ↗ icon (for recent items) or subject chip (when
/// [suggestion.subject] is non-null).
///
/// Minimum tap target is 48 × 48 px. Wrapped in [Semantics] for accessibility.
class SuggestionRowWidget extends StatelessWidget {
  const SuggestionRowWidget({
    super.key,
    required this.suggestion,
    required this.query,
    required this.onTap,
  });

  final SearchSuggestion suggestion;

  /// The current typed text; used to split the display text into normal +
  /// bold segments.
  final String query;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${suggestion.displayText}, suggestion',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // ── Leading icon ────────────────────────────────────────────
                _LeadingIcon(type: suggestion.type),
                const SizedBox(width: 12),

                // ── Suggestion text ─────────────────────────────────────────
                Expanded(
                  child: _SuggestionText(suggestion: suggestion, query: query),
                ),

                const SizedBox(width: 8),

                // ── Trailing widget ─────────────────────────────────────────
                _TrailingWidget(suggestion: suggestion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Leading icon ──────────────────────────────────────────────────────────────

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.type});

  final SuggestionType type;

  static const _kPurple = Color(0xFF7C3AED);
  static const _kMuted = AppColors.hint;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case SuggestionType.recent:
        return const Icon(Icons.history, size: 18, color: _kMuted);
      case SuggestionType.hashtag:
        return const Icon(Icons.tag, size: 18, color: _kPurple);
      case SuggestionType.sessionName:
      case SuggestionType.host:
        return const Icon(Icons.search, size: 18, color: _kMuted);
    }
  }
}

// ── Suggestion text with bold completion ──────────────────────────────────────

class _SuggestionText extends StatelessWidget {
  const _SuggestionText({required this.suggestion, required this.query});

  final SearchSuggestion suggestion;
  final String query;

  @override
  Widget build(BuildContext context) {
    final text = suggestion.displayText;

    // When query is empty (e.g., recent / hashtag shown on empty input), render
    // the full text in normal weight with no bold split.
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        overflow: TextOverflow.ellipsis,
      );
    }

    // Case-insensitive prefix detection.
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      // Fallback: render full text bold (entire text is a "completion").
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.text,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final before = text.substring(0, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        children: [
          // Typed portion — normal weight.
          TextSpan(text: before),
          // Completion portion — bold.
          TextSpan(
            text: after,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Trailing widget ───────────────────────────────────────────────────────────

class _TrailingWidget extends StatelessWidget {
  const _TrailingWidget({required this.suggestion});

  final SearchSuggestion suggestion;

  static const _kMuted = AppColors.hint;

  @override
  Widget build(BuildContext context) {
    if (suggestion.type == SuggestionType.recent) {
      return const Icon(Icons.north_east, size: 16, color: _kMuted);
    }

    final subject = suggestion.subject;
    if (subject != null) {
      return _SubjectChip(label: subject);
    }

    return const SizedBox.shrink();
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label});

  final String label;

  static const _kPurple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPurple, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: _kPurple,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
