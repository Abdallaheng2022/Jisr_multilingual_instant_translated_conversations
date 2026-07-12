import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// حالة المصادقة: تسجيل الدخول، ومزامنة المستخدم مع قاعدة البيانات.
class AuthState extends ChangeNotifier {
  AuthState({required this.auth, required this.db}) {
    _init();
  }

  final AuthService auth;
  final DatabaseService db;

  AppUser? user;
  bool loading = false;
  bool ready = false;
  String? error;

  bool get isSignedIn => user != null;

  void _init() {
    // استمع لتغيّر حالة الدخول — بمعالجة أخطاء إن كان الخادم غير مُعّد
    try {
      auth.authStateChanges().listen((u) async {
        if (u != null) {
          try {
            var dbUser = await db.getUser(u.uid);
            if (dbUser == null) {
              dbUser = u;
              await db.saveUser(dbUser);
            }
            user = dbUser;
          } catch (e) {
            user = u; // فشل قاعدة البيانات — استخدم بيانات المصادقة الأساسية
          }
        } else {
          user = null;
        }
        ready = true;
        notifyListeners();
      }, onError: (e) {
        ready = true;
        notifyListeners();
      });
    } catch (e) {
      // الخادم غير مُعّد — علّم الحالة كجاهزة (بلا مستخدم)
      ready = true;
      debugPrint('AuthState: الخادم غير متاح: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.signInWithGoogle();
      // authStateChanges will update user
    } catch (e) {
      error = 'فشل تسجيل الدخول عبر Google: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Sign up with email + password + display name
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Sign in with email + password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.signInWithEmail(email: email, password: password);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    // رسائل Supabase الفعلية
    if (s.contains('invalid login') ||
        (s.contains('invalid') && s.contains('credential'))) {
      return 'البريد أو كلمة المرور غير صحيحة — أو الحساب غير مسجّل';
    }
    if (s.contains('email not confirmed') || s.contains('not confirmed')) {
      return 'لم تُؤكّد بريدك بعد — تحقق من رسالة التأكيد';
    }
    if (s.contains('already registered') ||
        s.contains('already been registered') ||
        s.contains('user already')) {
      return 'هذا البريد مسجّل بالفعل — سجّل الدخول بدل إنشاء حساب';
    }
    if (s.contains('password') && s.contains('6')) {
      return 'كلمة المرور قصيرة (6 أحرف على الأقل)';
    }
    if (s.contains('password')) {
      return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
    }
    if (s.contains('invalid email') || s.contains('unable to validate email')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (s.contains('network') ||
        s.contains('socket') ||
        s.contains('timeout')) {
      return 'تعذّر الاتصال — تحقق من الإنترنت';
    }
    if (s.contains('rate limit') || s.contains('too many')) {
      return 'محاولات كثيرة — انتظر قليلاً ثم أعد المحاولة';
    }
    return 'تعذّر تسجيل الدخول. تأكد من البيانات وحاول مجدداً';
  }

  Future<void> signOut() async {
    await auth.signOut();
    user = null;
    notifyListeners();
  }

  /// تحديث موافقة المساهمة في التدريب
  Future<void> setContributeToTraining(bool value) async {
    if (user == null) return;
    user = user!.copyWith(contributeToTraining: value);
    await db.updateUser(user!.uid, {'contributeToTraining': value});
    notifyListeners();
  }

  /// تحديث الاشتراك بعد الشراء
  Future<void> setSubscribed(String plan) async {
    if (user == null) return;
    user = user!.copyWith(subscribed: true, plan: plan);
    await db.updateUser(user!.uid, {'subscribed': true, 'plan': plan});
    notifyListeners();
  }

  /// خصم رسالة من الرصيد المجاني
  Future<void> consumeMessage() async {
    if (user == null || user!.subscribed) return;
    final newCount = user!.usedMessages + 1;
    user = user!.copyWith(usedMessages: newCount);
    await db.updateUser(user!.uid, {'usedMessages': newCount});
    notifyListeners();
  }
}
