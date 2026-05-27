// Pure-Dart tests for the profile score formula (ADR 0009 Sub-decision 3).
//
// Formula: newScore = ((thumbsUp + 1) / max(1, endedSessions)).clamp(0.0, 1.0)
//
// The +1 accounts for the rating being written in this batch iteration.
// When endedSessions == 0, denominator falls back to 1 (safe-divide guard).
// The clamp prevents profileScore from exceeding 1.0 when multiple raters
// thumb-up the same ratee in a single session.

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the formula in RatingRepositoryImpl.submitRatings.
double _computeNewScore(int thumbsUp, int endedSessions) {
  final denominator = endedSessions > 0 ? endedSessions : 1;
  return ((thumbsUp + 1) / denominator).clamp(0.0, 1.0);
}

void main() {
  group('profile score formula — baseline cases', () {
    test('first rating for a user with 1 ended session yields 1.0', () {
      // thumbsUp = 0 (no prior ratings), endedSessions = 1
      // newScore = (0 + 1) / 1 = 1.0
      expect(_computeNewScore(0, 1), 1.0);
    });

    test('first rating with 2 ended sessions yields 0.5', () {
      // newScore = (0 + 1) / 2 = 0.5
      expect(_computeNewScore(0, 2), 0.5);
    });

    test('one prior thumbs-up with 2 ended sessions yields 1.0', () {
      // newScore = (1 + 1) / 2 = 1.0
      expect(_computeNewScore(1, 2), 1.0);
    });

    test('2 prior thumbs-up with 4 ended sessions yields 0.75', () {
      // newScore = (2 + 1) / 4 = 0.75
      expect(_computeNewScore(2, 4), 0.75);
    });
  });

  group('profile score formula — edge case: endedSessions == 0', () {
    test(
      'endedSessions 0 with 0 thumbsUp — denominator clamps to 1, score is 1.0',
      () {
        // denominator = max(1, 0) = 1; (0 + 1) / 1 = 1.0
        // This edge case arises when the rating is submitted before the session
        // count query reflects the ended session.
        expect(_computeNewScore(0, 0), 1.0);
      },
    );

    test(
      'endedSessions 0 with non-zero thumbsUp — score is clamped to 1.0',
      () {
        expect(_computeNewScore(5, 0), 1.0);
      },
    );
  });

  group('profile score formula — clamp: score cannot exceed 1.0', () {
    test(
      'multiple raters in one session — raw ratio above 1 is clamped to 1.0',
      () {
        // e.g. 5 thumbsUp for 1 endedSession → raw = 6/1 = 6.0 → clamped to 1.0
        expect(_computeNewScore(5, 1), 1.0);
      },
    );

    test('raw ratio exactly 1.0 is not clamped', () {
      expect(_computeNewScore(3, 4), closeTo(1.0, 0.001));
    });
  });

  group('profile score formula — clamp: score cannot go below 0.0', () {
    // The +1 in the numerator guarantees the result is always ≥ 1/denominator > 0.
    // Even so, clamp(0.0, 1.0) ensures no negative output is possible.
    test('any valid input produces a non-negative score', () {
      final scores = [
        _computeNewScore(0, 1),
        _computeNewScore(0, 100),
        _computeNewScore(0, 0),
      ];
      for (final s in scores) {
        expect(s, greaterThanOrEqualTo(0.0));
      }
    });
  });

  group('profile score formula — realistic scenarios', () {
    test('after many sessions with all thumbs-up score approaches 1.0', () {
      // 9 prior thumbsUp, 10 ended sessions → (9+1)/10 = 1.0
      expect(_computeNewScore(9, 10), 1.0);
    });

    test('consistent 50% rating — score stays near 0.5', () {
      // 4 thumbsUp, 10 ended sessions → 5/10 = 0.5
      expect(_computeNewScore(4, 10), 0.5);
    });

    test('formula is deterministic given same inputs', () {
      final a = _computeNewScore(3, 7);
      final b = _computeNewScore(3, 7);
      expect(a, equals(b));
    });
  });
}
