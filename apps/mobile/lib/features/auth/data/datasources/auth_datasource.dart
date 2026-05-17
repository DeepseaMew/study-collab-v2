import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';

class AuthDatasource {
  const AuthDatasource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  /// Convenience factory that wires the Firebase singletons automatically.
  factory AuthDatasource.create() => AuthDatasource(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the UID of the current user, or `null` when signed out.
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Returns the email of the current user, or `null` when signed out.
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Returns the displayName stored on the Firebase Auth user, or `null`.
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  /// Returns whether the current user's email address has been verified.
  bool get currentUserEmailVerified =>
      _auth.currentUser?.emailVerified ?? false;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e, st) {
      appLogger.error(
        'signInWithEmailAndPassword failed',
        exception: e.code,
        stackTrace: st,
      );
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'signInWithEmailAndPassword unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e, st) {
      appLogger.error(
        'createUserWithEmailAndPassword failed',
        exception: e.code,
        stackTrace: st,
      );
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'createUserWithEmailAndPassword unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser!.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e, st) {
      appLogger.error(
        'updateDisplayName failed',
        exception: e.code,
        stackTrace: st,
      );
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'updateDisplayName unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser!.sendEmailVerification();
    } on FirebaseAuthException catch (e, st) {
      appLogger.error(
        'sendEmailVerification failed',
        exception: e.code,
        stackTrace: st,
      );
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'sendEmailVerification unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser!.reload();
      await _auth.currentUser!.getIdToken(true);
    } on FirebaseAuthException catch (e, st) {
      appLogger.error(
        'reloadCurrentUser failed',
        exception: e.code,
        stackTrace: st,
      );
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'reloadCurrentUser unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e, st) {
      appLogger.error('signOut failed', exception: e.code, stackTrace: st);
      throw _mapFirebaseException(e);
    } catch (e, st) {
      appLogger.error(
        'signOut unexpected error',
        exception: '${e.runtimeType}: $e',
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  Future<void> createUserDocument({
    required String uid,
    required String fullName,
    required String email,
  }) => _firestore.doc(FirestorePaths.userDoc(uid)).set({
    'uid': uid,
    'displayName': fullName,
    'fullName': fullName,
    'email': email,
    'photoUrl': null,
    'hasHostedBefore': false,
    'studentYear': 1,
    'academicLevel': 'undergraduate',
    'faculty': '',
    'bio': '',
    'profileScore': 0.0,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(
    String uid, {
    bool forceServer = false,
  }) {
    final options = forceServer
        ? const GetOptions(source: Source.server)
        : null;
    return _firestore.doc(FirestorePaths.userDoc(uid)).get(options);
  }

  Future<void> updateUserDocument({
    required String uid,
    required String displayName,
    required String faculty,
    required String bio,
  }) => _firestore.doc(FirestorePaths.userDoc(uid)).update({
    'displayName': displayName,
    'faculty': faculty,
    'bio': bio,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Translates [FirebaseAuthException] error codes to typed [AuthFailure] values.
  AuthFailure _mapFirebaseException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-email' => const AuthFailure.invalidCredentials(),
      'network-request-failed' => const AuthFailure.networkFailure(),
      'email-already-in-use' => const AuthFailure.unknownFailure(
        'An account with this email already exists.',
      ),
      _ => const AuthFailure.unknownFailure(),
    };
  }
}
