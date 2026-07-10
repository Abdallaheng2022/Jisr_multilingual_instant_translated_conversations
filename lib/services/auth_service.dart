import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

/// خدمة المصادقة: تسجيل الدخول عبر Google باستخدام Firebase Auth.
class AuthService {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// المستخدم الحالي (أو null)
  AppUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return AppUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      photoUrl: u.photoURL,
    );
  }

  /// تدفّق تغيّر حالة الدخول
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null
          ? null
          : AppUser(
              uid: u.uid,
              email: u.email,
              displayName: u.displayName,
              photoUrl: u.photoURL,
            ));

  /// تسجيل الدخول بـ Google
  Future<AppUser?> signInWithGoogle() async {
    // 1) اختيار حساب Google
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // ألغى المستخدم

    // 2) الحصول على بيانات المصادقة
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 3) الدخول لـ Firebase
    final userCred = await _auth.signInWithCredential(credential);
    final u = userCred.user;
    if (u == null) return null;

    return AppUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      photoUrl: u.photoURL,
    );
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
