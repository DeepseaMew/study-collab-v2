import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

/// Domain entity representing a Study Collab user.
///
/// Mirrors the `users/{uid}` Firestore schema defined in ADR 0001.
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String uid,
    required String displayName,
    required String fullName,
    required String email,
    String? photoUrl,
    required bool hasHostedBefore,
    required int studentYear,
    required String academicLevel,
    required String faculty,
    String? bio,
    required double profileScore,
  }) = _UserEntity;
}
