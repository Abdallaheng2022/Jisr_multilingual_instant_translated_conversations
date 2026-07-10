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
    // استمع لتغيّر حالة الدخول
    auth.authStateChanges().listen((u) async {
      if (u != null) {
        // اجلب/أنشئ سجل المستخدم في قاعدة البيانات
        var dbUser = await db.getUser(u.uid);
        if (dbUser == null) {
          dbUser = u; // أول دخول — أنشئ سجلاً
          await db.saveUser(dbUser);
        }
        user = dbUser;
      } else {
        user = null;
      }
      ready = true;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.signInWithGoogle();
      // authStateChanges سيحدّث user تلقائياً
    } catch (e) {
      error = 'فشل تسجيل الدخول: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
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
