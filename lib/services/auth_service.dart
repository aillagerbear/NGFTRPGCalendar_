import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthService() {
    developer.log('AuthService initialized', name: 'AuthService');
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get user => _auth.authStateChanges();

  Future<void> createOrUpdateUserDocument(User user) async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Creating or updating user document for user: ${user.uid}', name: 'AuthService');
      DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);

      DocumentSnapshot doc = await userDocRef.get();
      if (!doc.exists) {
        developer.log('Creating new user document', name: 'AuthService');
        await userDocRef.set({
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSignInTime': FieldValue.serverTimestamp(),
        });
        developer.log('New user document created', name: 'AuthService');
      } else {
        developer.log('Updating existing user document', name: 'AuthService');
        await userDocRef.update({
          'lastSignInTime': FieldValue.serverTimestamp(),
        });
        developer.log('User document updated', name: 'AuthService');
      }
    } catch (e) {
      developer.log('Error in createOrUpdateUserDocument: $e', name: 'AuthService');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> signInAnonymously() async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Attempting anonymous sign in', name: 'AuthService');
      UserCredential result = await _auth.signInAnonymously();
      developer.log('Anonymous sign in successful. User ID: ${result.user?.uid}', name: 'AuthService');
      return result.user;
    } catch (e) {
      developer.log('Anonymous sign in error: ${e.toString()}', name: 'AuthService');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Attempting sign in with email: $email', name: 'AuthService');
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      developer.log('Sign in successful. User ID: ${result.user?.uid}', name: 'AuthService');
      await createOrUpdateUserDocument(result.user!);
      return result.user;
    } catch (e) {
      developer.log('Sign in error: ${e.toString()}', name: 'AuthService');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Attempting registration with email: $email', name: 'AuthService');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      developer.log('Registration successful. User ID: ${result.user?.uid}', name: 'AuthService');
      await createOrUpdateUserDocument(result.user!);
      return result.user;
    } catch (e) {
      developer.log('Registration error: ${e.toString()}', name: 'AuthService');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Attempting Google sign in', name: 'AuthService');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Google sign in cancelled by user', name: 'AuthService');
        return null;
      }

      developer.log('Getting Google auth details', name: 'AuthService');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log('Signing in to Firebase with Google credential', name: 'AuthService');
      UserCredential result = await _auth.signInWithCredential(credential);
      developer.log('Google sign in successful. User ID: ${result.user?.uid}', name: 'AuthService');
      await createOrUpdateUserDocument(result.user!);
      return result;
    } catch (e) {
      developer.log('Google sign in error: ${e.toString()}', name: 'AuthService');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Signing out user', name: 'AuthService');
      await _googleSignIn.signOut();
      await _auth.signOut();
      developer.log('User signed out successfully', name: 'AuthService');
    } catch (e) {
      developer.log('Error signing out: ${e.toString()}', name: 'AuthService');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserName(String newName) async {
    _isLoading = true;
    notifyListeners();
    User? user = _auth.currentUser;
    developer.log('Updating user name to: $newName', name: 'AuthService');
    if (user != null) {
      try {
        developer.log('Updating Firestore document', name: 'AuthService');
        await _firestore.collection('users').doc(user.uid).update({
          'displayName': newName,
        });
        developer.log('Firestore document updated', name: 'AuthService');

        developer.log('Updating Firebase user profile', name: 'AuthService');
        await user.updateDisplayName(newName);
        developer.log('Firebase user profile updated', name: 'AuthService');

        developer.log('User name updated successfully', name: 'AuthService');
      } catch (e) {
        developer.log('Error updating user name: $e', name: 'AuthService');
        throw e;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _isLoading = false;
      notifyListeners();
      developer.log('No user is currently signed in.', name: 'AuthService');
      throw Exception('No user is currently signed in.');
    }
  }

  Future<void> updateUserPhoto(File imageFile) async {
    _isLoading = true;
    notifyListeners();
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        developer.log('Updating photo for user: ${user.uid}', name: 'AuthService');

        developer.log('Refreshing user token', name: 'AuthService');
        await user.getIdToken(true);

        String fileName = 'profile.jpg';
        final ref = _storage.ref().child('profileImages/${user.uid}/$fileName');
        developer.log('Uploading to path: profileImages/${user.uid}/$fileName', name: 'AuthService');

        final metadata = await imageFile.stat();
        developer.log('File size: ${metadata.size} bytes', name: 'AuthService');

        final uploadMetadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': user.uid},
        );

        developer.log('Starting file upload', name: 'AuthService');
        final uploadTask = ref.putFile(imageFile, uploadMetadata);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          developer.log('Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}', name: 'AuthService');
        });

        await uploadTask;
        developer.log('File upload completed', name: 'AuthService');

        final url = await ref.getDownloadURL();
        developer.log('Uploaded image URL: $url', name: 'AuthService');

        developer.log('Updating Firebase user profile', name: 'AuthService');
        await user.updatePhotoURL(url);
        developer.log('Firebase user profile updated', name: 'AuthService');

        developer.log('Updating Firestore document', name: 'AuthService');
        await _firestore.collection('users').doc(user.uid).update({
          'photoURL': url,
        });
        developer.log('Firestore document updated', name: 'AuthService');

        developer.log('Photo update completed successfully', name: 'AuthService');
      } catch (e) {
        developer.log('Error updating user photo: $e', name: 'AuthService', error: e);
        if (e is FirebaseException) {
          developer.log('Firebase error code: ${e.code}', name: 'AuthService');
          developer.log('Firebase error message: ${e.message}', name: 'AuthService');
        }
        throw e;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _isLoading = false;
      notifyListeners();
      developer.log('No user is currently signed in.', name: 'AuthService');
      throw Exception('No user is currently signed in.');
    }
  }

  Future<void> updateUserPhotoWeb(Uint8List imageData) async {
    _isLoading = true;
    notifyListeners();
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        developer.log('Starting updateUserPhotoWeb for user: ${user.uid}', name: 'AuthService');

        developer.log('Refreshing user token', name: 'AuthService');
        await user.getIdToken(true);

        String fileName = 'profile.jpg';
        final ref = _storage.ref().child('profileImages/${user.uid}/$fileName');
        developer.log('Uploading to path: profileImages/${user.uid}/$fileName', name: 'AuthService');

        final uploadMetadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': user.uid},
        );
        developer.log('Metadata set: ${uploadMetadata.contentType}, userId: ${user.uid}', name: 'AuthService');

        developer.log('Starting file upload. Image data size: ${imageData.length} bytes', name: 'AuthService');
        final uploadTask = ref.putData(imageData, uploadMetadata);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          developer.log('Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}', name: 'AuthService');
        });

        await uploadTask;
        developer.log('File upload completed', name: 'AuthService');

        final url = await ref.getDownloadURL();
        developer.log('Uploaded image URL: $url', name: 'AuthService');

        developer.log('Updating Firebase user profile', name: 'AuthService');
        await user.updatePhotoURL(url);
        developer.log('Firebase user profile updated', name: 'AuthService');

        developer.log('Updating Firestore document', name: 'AuthService');
        await _firestore.collection('users').doc(user.uid).update({
          'photoURL': url,
        });
        developer.log('Firestore document updated', name: 'AuthService');

        developer.log('Photo update completed successfully', name: 'AuthService');
      } catch (e) {
        developer.log('Error updating user photo: $e', name: 'AuthService', error: e);
        if (e is FirebaseException) {
          developer.log('Firebase error code: ${e.code}', name: 'AuthService');
          developer.log('Firebase error message: ${e.message}', name: 'AuthService');
        }
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _isLoading = false;
      notifyListeners();
      developer.log('No user is currently signed in.', name: 'AuthService');
      throw Exception('No user is currently signed in.');
    }
  }
}