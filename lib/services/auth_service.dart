import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Auth service backed by Supabase.
/// Supports email/password sign-up & sign-in, and Google OAuth.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  /// Current signed-in user (or null)
  AppUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _mapUser(u);
  }

  AppUser _mapUser(User u) => AppUser(
        uid: u.id,
        email: u.email,
        displayName:
            u.userMetadata?['display_name'] as String? ?? u.email?.split('@').first,
        photoUrl: u.userMetadata?['avatar_url'] as String?,
      );

  /// Stream of auth state changes
  Stream<AppUser?> authStateChanges() =>
      _auth.onAuthStateChange.map((event) {
        final u = event.session?.user;
        return u == null ? null : _mapUser(u);
      });

  /// Sign up with email + password + display name
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    final u = res.user;
    return u == null ? null : _mapUser(u);
  }

  /// Sign in with email + password
  Future<AppUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    final u = res.user;
    if (u == null) {
      // Supabase قد يُرجع نتيجة فارغة بلا استثناء — نرمي خطأً واضحاً
      throw const AuthException('Invalid login credentials');
    }
    return _mapUser(u);
  }

  /// Sign in with Google (OAuth)
  /// يفتح صفحة Google، ويعود للتطبيق عبر الـ deep link
  Future<void> signInWithGoogle() async {
    final ok = await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.jisr.app://login-callback',
    );
    if (!ok) {
      throw const AuthException('تعذّر فتح صفحة Google');
    }
    // النتيجة تصل عبر authStateChanges بعد عودة الـ deep link
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
