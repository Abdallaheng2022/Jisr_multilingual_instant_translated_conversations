import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/billing_service.dart';

/// الحالة العامة للتطبيق: عدّاد الرسائل المجانية، الاشتراك، اللغات، الاتصال.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.billing}) {
    _init();
  }

  final ApiService api;
  final BillingService billing;

  static const _kUsedKey = 'jisr_used_messages';
  static const _kSubKey = 'jisr_subscribed';
  static const _kSubTypeKey = 'jisr_sub_type';
  static const freeLimit = 10; // 10 رسائل مجانية

  late SharedPreferences _prefs;

  // اللغات المختارة
  Language sourceLang = kLanguages[0]; // العربية
  Language targetLang = kLanguages[2]; // التركية

  // الحالة
  int usedMessages = 0;
  bool subscribed = false;
  PlanType currentPlan = PlanType.free;
  HealthStatus health = HealthStatus.offline;
  bool ready = false;

  int get freeRemaining => (freeLimit - usedMessages).clamp(0, freeLimit);
  bool get canTranslate => subscribed || freeRemaining > 0;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    usedMessages = _prefs.getInt(_kUsedKey) ?? 0;
    subscribed = _prefs.getBool(_kSubKey) ?? false;
    final t = _prefs.getString(_kSubTypeKey);
    currentPlan = switch (t) {
      'monthly' => PlanType.monthly,
      'yearly' => PlanType.yearly,
      _ => PlanType.free,
    };

    // ربط نتائج الشراء بالحالة
    billing.onPurchaseSuccess = _handlePurchase;
    await billing.init();

    ready = true;
    notifyListeners();

    // فحص الاتصال بالخلفية
    refreshHealth();
  }

  Future<void> refreshHealth() async {
    health = await api.checkHealth();
    notifyListeners();
  }

  void swapLanguages() {
    final tmp = sourceLang;
    sourceLang = targetLang;
    targetLang = tmp;
    notifyListeners();
  }

  void setSource(Language l) {
    sourceLang = l;
    notifyListeners();
  }

  void setTarget(Language l) {
    targetLang = l;
    notifyListeners();
  }

  /// تُستدعى بعد كل ترجمة ناجحة لخصم رسالة من الرصيد المجاني
  Future<void> consumeMessage() async {
    if (subscribed) return; // المشتركون بلا حد
    usedMessages++;
    await _prefs.setInt(_kUsedKey, usedMessages);
    notifyListeners();
  }

  void _handlePurchase(String productId) {
    subscribed = true;
    currentPlan =
        productId.contains('yearly') ? PlanType.yearly : PlanType.monthly;
    _prefs.setBool(_kSubKey, true);
    _prefs.setString(
        _kSubTypeKey, currentPlan == PlanType.yearly ? 'yearly' : 'monthly');
    notifyListeners();
  }

  Future<void> buyPlan(SubscriptionPlan plan) => billing.buy(plan.id);
  Future<void> restorePurchases() => billing.restore();

  /// (للتجربة فقط) إعادة تعيين الرصيد المجاني
  Future<void> debugReset() async {
    usedMessages = 0;
    subscribed = false;
    currentPlan = PlanType.free;
    await _prefs.remove(_kUsedKey);
    await _prefs.remove(_kSubKey);
    await _prefs.remove(_kSubTypeKey);
    notifyListeners();
  }
}
