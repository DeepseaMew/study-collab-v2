import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';

part 'group_chat_summary_model.freezed.dart';
part 'group_chat_summary_model.g.dart';

/// Data-layer model for a `users/{uid}/groupChats/{sessionId}` document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [GroupChatSummary].
///
/// Timestamps are stored as epoch milliseconds so that the model has zero
/// dependency on `cloud_firestore` types; the datasource converts [Timestamp]
/// values before calling [GroupChatSummaryModel.fromJson].
@freezed
abstract class GroupChatSummaryModel with _$GroupChatSummaryModel {
  const GroupChatSummaryModel._();

  const factory GroupChatSummaryModel({
    required String sessionId,
    required String sessionTitle,
    String? lastMessageText,
    @_NullableEpochConverter() DateTime? lastMessageAt,
    @Default(0) int unreadCount,
  }) = _GroupChatSummaryModel;

  factory GroupChatSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$GroupChatSummaryModelFromJson(json);

  GroupChatSummary toEntity() => GroupChatSummary(
    sessionId: sessionId,
    sessionTitle: sessionTitle,
    lastMessageText: lastMessageText,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount,
  );
}

/// Nullable variant for optional timestamp fields.
class _NullableEpochConverter implements JsonConverter<DateTime?, Object?> {
  const _NullableEpochConverter();

  @override
  DateTime? fromJson(Object? value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  Object? toJson(DateTime? dt) => dt?.millisecondsSinceEpoch;
}
