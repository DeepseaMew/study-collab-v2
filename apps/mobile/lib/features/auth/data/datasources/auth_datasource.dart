import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/firestore_paths.dart';

class AuthDatasource {
  const AuthDatasource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendEmailVerification() =>
      _auth.currentUser!.sendEmailVerification();

  Future<void> reloadCurrentUser() => _auth.currentUser!.reload();

  Future<void> signOut() => _auth.signOut();

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

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(String uid) =>
      _firestore.doc(FirestorePaths.userDoc(uid)).get();

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
}
