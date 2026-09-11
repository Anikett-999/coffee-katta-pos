import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/user_model.dart';
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? profileIssueMessage;

  User? get currentUser => _auth.currentUser;
  
  bool _hasSavedPin = false;
  bool get hasSavedPin => _hasSavedPin;

  AuthService() {
    _init();
  }

  void _init() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSavedPin = prefs.getString('saved_pin') != null;
    notifyListeners();
    // Re-notify when auth state changes
    _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  Future<String?> loginWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      profileIssueMessage = null;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Update last login timestamp safely
      await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> sendResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address provided is invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the administrator.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later or reset your password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'email-already-in-use':
        return 'This email is already in use by another account.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }

  bool unlockWithPin(String pin) {
    // Stub valid PIN check, to be expanded if necessary
    if (pin == '1234') return true; 
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // Legacy API from ShreeRajmandir implementation
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  Future<void> registerUser(String email, String password, String name, String role, List<String> branchIds) async {
    FirebaseApp app = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      final userCredential = await FirebaseAuth.instanceFor(app: app)
          .createUserWithEmailAndPassword(email: email, password: password);
      
      final user = UserModel(
        userId: userCredential.user!.uid,
        name: name,
        email: email,
        role: role,
        branchIds: branchIds,
      );
      
      await _firestore.collection('users').doc(user.userId).set(user.toJson());
      
      await app.delete();
    } catch (e) {
      await app.delete();
      rethrow;
    }
  }

  Future<String?> requestAccountDeletion() async {
    try {
      _setLoading(true);
      final user = _auth.currentUser;
      if (user != null) {
        final userData = await getCurrentUserData();
        
        await _firestore.collection('account_deletion_requests').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'name': userData?.name ?? 'Unknown',
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'note': 'Automated cleanup request from Waiter Module',
        });
        
        return null; // success
      }
      return 'No active session found.';
    } catch (e) {
      return 'An unexpected error occurred while requesting deletion.';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> deleteAccount() async {
    // Keep this for admin-level physical cleanup or re-authentication flows
    try {
      _setLoading(true);
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();
        return null;
      }
      return 'No active session found.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please log out and log in again to perform this sensitive action.';
      }
      return _mapFirebaseAuthError(e);
    } catch (e) {
      return 'An unexpected error occurred during account deletion.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleUserActiveStatus(String userId, bool currentStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });
    } catch (e) {
      throw 'Failed to update user status: $e';
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw 'Failed to update user data: $e';
    }
  }
}
