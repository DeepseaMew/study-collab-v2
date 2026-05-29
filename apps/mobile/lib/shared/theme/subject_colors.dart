import 'package:flutter/material.dart';

typedef SubjectColors = ({Color background, Color text, Color border});

/// Returns subject-specific chip colors (background + text + border).
/// Matching is case-insensitive so free-text hashtags are handled correctly.
/// Falls back to a neutral grey for unknown subjects.
SubjectColors subjectColor(String subject) {
  return switch (subject.toLowerCase().trim()) {
    'computer science' => (
        background: const Color(0xFFEEEDFE),
        text: const Color(0xFF3C3489),
        border: const Color(0xFF3C3489),
      ),
    'mathematics' => (
        background: const Color(0xFFE6F1FB),
        text: const Color(0xFF0C447C),
        border: const Color(0xFF0C447C),
      ),
    'chemistry' => (
        background: const Color(0xFFFAECE7),
        text: const Color(0xFF712B13),
        border: const Color(0xFF712B13),
      ),
    'biology' => (
        background: const Color(0xFFE1F5EE),
        text: const Color(0xFF085041),
        border: const Color(0xFF085041),
      ),
    'economics' => (
        background: const Color(0xFFFAEEDA),
        text: const Color(0xFF633806),
        border: const Color(0xFF633806),
      ),
    'physics' => (
        background: const Color(0xFFEAF3DE),
        text: const Color(0xFF27500A),
        border: const Color(0xFF27500A),
      ),
    'english' => (
        background: const Color(0xFFFFE9E9),
        text: const Color(0xFF500809),
        border: const Color(0xFF500809),
      ),
    _ => (
        background: const Color(0xFFECECEC),
        text: const Color(0xFF888888),
        border: const Color(0xFF888888),
      ),
  };
}
