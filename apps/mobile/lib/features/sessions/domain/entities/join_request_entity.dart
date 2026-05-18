import 'package:freezed_annotation/freezed_annotation.dart';

part 'join_request_entity.freezed.dart';

/// Domain entity for a join request submitted by a user.
///
/// Mirrors the `sessions/{sessionId}/requests/{uid}` subcollection schema
/// defined in ADR 0001 Amendment 1 and ADR 0003.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class JoinRequestEntity with _$JoinRequestEntity {
  const factory JoinRequestEntity({
    required String uid,
    required String displayName,
    String? photoUrl,
    required DateTime requestedAt,
  }) = _JoinRequestEntity;
}
