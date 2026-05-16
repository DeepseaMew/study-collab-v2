import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.unverified() = Unverified;
  const factory AuthState.pendingProfileSetup() = PendingProfileSetup;
  const factory AuthState.authenticated() = Authenticated;
}
