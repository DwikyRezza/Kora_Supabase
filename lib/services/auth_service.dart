import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final _firestore = FirebaseFirestore.instance;

  /// Get currently signed in user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Sign in with Google (just authenticates, does NOT validate cloud existence)
  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print('[AuthService] Error signing in with Google: $e');
      return null;
    }
  }

  /// Cek apakah UID user sudah terdaftar di Firestore (sudah pernah Register)
  /// Return true = sudah ada, false = belum terdaftar
  static Future<bool> checkUserExistsInCloud() async {
    if (!isLoggedIn) return false;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      // Dianggap terdaftar jika dokumen ada dan memiliki field 'profile'
      return doc.exists && doc.data()!.containsKey('profile');
    } catch (e) {
      print('[AuthService] Error checking cloud user: $e');
      return false;
    }
  }

  /// Sign out dari Firebase + Google + bersihkan sesi lokal
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await clearLocalSession();
    } catch (e) {
      print('[AuthService] Error signing out: $e');
    }
  }

  /// Bersihkan semua data sesi & profil lokal (SharedPreferences)
  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Get user display name
  static String get displayName => currentUser?.displayName ?? 'Atlet';

  /// Get user email
  static String get email => currentUser?.email ?? '';

  /// Get user photo URL from Google
  static String? get photoUrl => currentUser?.photoURL;

  /// Get user UID
  static String get uid => currentUser?.uid ?? '';
}
