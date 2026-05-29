import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/sessions/data/models/session_model.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';

part 'join_request_model.freezed.dart';
part 'join_request_model.g.dart';

/// Data-layer model for a `sessions/{sessionId}/requests/{uid}` document.
@freezed
abstract class JoinRequestModel with _$JoinRequestModel {
  const JoinRequestModel._();

  const factory JoinRequestModel({
    required String uid,
    required String displayName,
    String? photoUrl,
    @TimestampConverter() required DateTime requestedAt,
  }) = _JoinRequestModel;

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) =>
      _$JoinRequestModelFromJson(json);

  /// Converts to the domain [JoinRequestEntity].
  JoinRequestEntity toEntity() => JoinRequestEntity(
    uid: uid,
    displayName: displayName,
    photoUrl: photoUrl,
    requestedAt: requestedAt,
  );
}
