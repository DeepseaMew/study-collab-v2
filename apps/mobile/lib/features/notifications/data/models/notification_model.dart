import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// Data-layer model for a `users/{uid}/notifications/{notifId}` document (ADR 0013).
///
/// Uses Freezed + json_serializable for serialization.
/// [_TimestampConverter] handles Firestore Timestamp ↔ DateTime.
/// Use [toEntity] to cross the domain boundary.
@freezed
abstract class NotificationModel with _$NotificationModel {
  const NotificationModel._();

  const factory NotificationModel({
    required String notifId,
    required String type,
    required String actorUid,
    required String actorDisplayName,
    String? sessionId,
    String? sessionTitle,
    required bool isRead,
    @_TimestampConverter() required DateTime createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  /// Converts to the domain [NotificationEntity].
  NotificationEntity toEntity() => NotificationEntity(
    notifId: notifId,
    type: NotificationType.fromString(type),
    actorUid: actorUid,
    actorDisplayName: actorDisplayName,
    sessionId: sessionId,
    sessionTitle: sessionTitle,
    isRead: isRead,
    createdAt: createdAt,
  );
}

/// Converts Firestore [Timestamp] ↔ [DateTime] for [NotificationModel.createdAt].
class _TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const _TimestampConverter();

  @override
  DateTime fromJson(Timestamp ts) => ts.toDate();

  @override
  Timestamp toJson(DateTime dt) => Timestamp.fromDate(dt);
}
