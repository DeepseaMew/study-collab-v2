import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_auth_state_provider.g.dart';

@riverpod
Stream<User?> firebaseAuthState(FirebaseAuthStateRef ref) {
  return FirebaseAuth.instance.authStateChanges();
}
