import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Data-layer model for a Firestore `users/{uid}` document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [UserEntity].
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String uid,
    required String displayName,
    required String fullName,
    required String email,
    String? photoUrl,
    @Default(false) bool hasHostedBefore,
    @Default(1) int studentYear,
    @Default('undergraduate') String academicLevel,
    @Default('') String faculty,
    String? bio,
    @Default(0.0) double profileScore,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Converts to the domain [UserEntity].
  UserEntity toEntity() => UserEntity(
    uid: uid,
    displayName: displayName,
    fullName: fullName,
    email: email,
    photoUrl: photoUrl,
    hasHostedBefore: hasHostedBefore,
    studentYear: studentYear,
    academicLevel: academicLevel,
    faculty: faculty,
    bio: bio,
    profileScore: profileScore,
  );
}
