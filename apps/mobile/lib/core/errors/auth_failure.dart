import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_failure.freezed.dart';

@freezed
sealed class AuthFailure with _$AuthFailure {
  const factory AuthFailure.invalidCredentials() = InvalidCredentials;
  const factory AuthFailure.emailNotVerified() = EmailNotVerified;
  const factory AuthFailure.kmuttDomainRejected() = KmuttDomainRejected;
  const factory AuthFailure.networkFailure() = NetworkFailure;
  const factory AuthFailure.unknownFailure([String? message]) = UnknownFailure;
}
