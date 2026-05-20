import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_entity.freezed.dart';

/// Domain entity representing one side of a bidirectional friendship record.
///
/// Mirrors the `users/{uid}/friends/{friendUid}` Firestore schema defined in
/// ADR 0001 (amended by ADR 0004).
///
/// The `status` field is a raw Firestore string (`'pending'` | `'accepted'`).
/// Use [FriendshipStatus] (from the same package) when you need a typed
/// view of the relationship from the current user's perspective.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class FriendEntity with _$FriendEntity {
  const factory FriendEntity({
    /// UID of the friend; matches the Firestore document ID.
    required String friendUid,

    /// Raw Firestore status string: `'pending'` or `'accepted'`.
    required String status,

    /// UID of the user who initiated the request.
    required String initiatorUid,

    /// When the request was first created.
    required DateTime createdAt,

    /// When the record was last updated (status change, display field write).
    required DateTime updatedAt,

    /// Denormalized display name of the friend, populated at accept time.
    /// Empty string on pending documents (not yet populated).
    required String friendDisplayName,

    /// Denormalized photo URL of the friend, populated at accept time.
    /// Null on pending documents.
    String? friendPhotoUrl,
  }) = _FriendEntity;
}
