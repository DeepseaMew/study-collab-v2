// Unit tests for SessionEntity derived fields.
//
// Domain coverage: SessionEntity.participantCount, spotsLeft, isFull — all
// three derived fields specified in ADR 0003.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

SessionEntity _session({
  required int capacity,
  required List<String> memberUids,
}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: 'sess-1',
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Test Session',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: memberUids,
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: capacity,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('SessionEntity.participantCount', () {
    test('returns memberUids length', () {
      final s = _session(capacity: 10, memberUids: ['a', 'b', 'c']);
      expect(s.participantCount, 3);
    });

    test('returns 0 when memberUids is empty', () {
      final s = _session(capacity: 10, memberUids: const []);
      expect(s.participantCount, 0);
    });
  });

  group('SessionEntity.spotsLeft', () {
    test('returns capacity minus member count', () {
      final s = _session(capacity: 10, memberUids: ['a', 'b', 'c']);
      expect(s.spotsLeft, 7);
    });

    test('clamps to 0 when over-capacity', () {
      final s = _session(capacity: 2, memberUids: ['a', 'b', 'c']);
      expect(s.spotsLeft, 0);
    });

    test('returns full capacity when no members', () {
      final s = _session(capacity: 5, memberUids: const []);
      expect(s.spotsLeft, 5);
    });
  });

  group('SessionEntity.isFull', () {
    test('returns false when under capacity', () {
      final s = _session(capacity: 5, memberUids: ['a']);
      expect(s.isFull, isFalse);
    });

    test('returns true when at capacity', () {
      final s = _session(capacity: 2, memberUids: ['a', 'b']);
      expect(s.isFull, isTrue);
    });

    test('returns true when over-capacity', () {
      final s = _session(capacity: 1, memberUids: ['a', 'b']);
      expect(s.isFull, isTrue);
    });

    test('returns false for empty session with non-zero capacity', () {
      final s = _session(capacity: 3, memberUids: const []);
      expect(s.isFull, isFalse);
    });
  });

  group('SessionEntity equality via Freezed', () {
    test('two identical sessions are equal', () {
      final s1 = _session(capacity: 5, memberUids: ['a']);
      final s2 = _session(capacity: 5, memberUids: ['a']);
      expect(s1, equals(s2));
    });

    test('sessions with different capacities are not equal', () {
      final s1 = _session(capacity: 5, memberUids: ['a']);
      final s2 = _session(capacity: 6, memberUids: ['a']);
      expect(s1, isNot(equals(s2)));
    });
  });

  group('SessionEntity.copyWith', () {
    test('copyWith title updates title, leaves other fields intact', () {
      final s = _session(capacity: 5, memberUids: ['a']);
      final updated = s.copyWith(title: 'Updated Title');
      expect(updated.title, 'Updated Title');
      expect(updated.capacity, 5);
      expect(updated.memberUids, ['a']);
    });
  });
}
