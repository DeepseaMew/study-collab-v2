import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_entity.freezed.dart';

/// Domain entity for a study session.
///
/// Fields follow ADR 0001 schema plus the five additions from Amendment 1
/// (location, scheduledEndAt, capacity, hostDisplayName, hostPhotoUrl) and
/// three derived fields computed by the repository layer.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class SessionEntity with _$SessionEntity {
  const SessionEntity._();

  const factory SessionEntity({
    required String sessionId,
    required String hostUid,
    required String hostFaculty,
    required String title,
    String? description,
    required List<String> hashtags,
    required String academicLevel,
    required int studentYear,
    required String visibility,
    required List<String> memberUids,
    required int noteCount,
    required String status,
    required DateTime scheduledAt,
    DateTime? scheduledEndAt,
    DateTime? endedAt,
    required String location,
    required int capacity,
    required String hostDisplayName,
    String? hostPhotoUrl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SessionEntity;

  // ── Derived fields ────────────────────────────────────────────────────────

  /// Number of current participants (including host).
  int get participantCount => memberUids.length;

  /// How many spots remain before the session is full.
  int get spotsLeft => (capacity - memberUids.length).clamp(0, capacity);

  /// Whether the session has reached its participant limit.
  bool get isFull => memberUids.length >= capacity;
}
