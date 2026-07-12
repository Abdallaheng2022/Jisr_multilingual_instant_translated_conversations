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
  static const _kVoiceTrialKey = 'jisr_voice_trial_used'; // ثوانٍ مستخدمة
  static const _kVoiceNotesKey = 'jisr_voice_notes_used'; // رسائل واتساب مستخدمة
  static const freeLimit = 10; // 10 رسائل مجانية
  static const voiceTrialSeconds = 180; // 3 دقائق مجانية للغرفة الصوتية
  static const voiceNotesLimit = 3; // 3 رسائل واتساب مجانية

  late SharedPreferences _prefs;

  // اللغات المختارة
  Language sourceLang = kLanguages[0]; // العربية (قسم الترجمة)
  Language targetLang = kLanguages[2]; // التركية (قسم الترجمة)

  // لغات مستقلة لقسم الواتساب (منفصلة عن قسم الترجمة)
  Language vnSourceLang = kLanguages[0];
  Language vnTargetLang = kLanguages[2];

  // الحالة
  int usedMessages = 0;
  bool subscribed = false;
  int voiceTrialUsed = 0; // ثوانٍ مستُهلكة من تجربة الغرفة الصوتية
  int voiceNotesUsed = 0; // رسائل واتساب مستُهلكة
  PlanType currentPlan = PlanType.free;
  HealthStatus health = HealthStatus.offline;
  bool ready = false;

  int get freeRemaining => (freeLimit - usedMessages).clamp(0, freeLimit);
  bool get canTranslate => subscribed || freeRemaining > 0;

  // الغرفة الصوتية: ثوانٍ مجانية متبقية، وهل يمكن الدخول
  int get voiceTrialRemaining =>
      (voiceTrialSeconds - voiceTrialUsed).clamp(0, voiceTrialSeconds);
  bool get canUseVoiceRoom => subscribed || voiceTrialRemaining > 0;

  // رسائل واتساب: عدد مجاني متبقٍ
  int get voiceNotesRemaining =>
      (voiceNotesLimit - voiceNotesUsed).clamp(0, voiceNotesLimit);
  bool get canTranslateVoiceNote => subscribed || voiceNotesRemaining > 0;

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      usedMessages = _prefs.getInt(_kUsedKey) ?? 0;
      subscribed = _prefs.getBool(_kSubKey) ?? false;
      voiceTrialUsed = _prefs.getInt(_kVoiceTrialKey) ?? 0;
      voiceNotesUsed = _prefs.getInt(_kVoiceNotesKey) ?? 0;
      final t = _prefs.getString(_kSubTypeKey);
      currentPlan = switch (t) {
        'monthly' => PlanType.monthly,
        'yearly' => PlanType.yearly,
        _ => PlanType.free,
      };

      // ربط نتائج الشراء بالحالة — بمهلة حتى لا يعلّق إن لم يستجب Google Play
      billing.onPurchaseSuccess = _handlePurchase;
      await billing.init().timeout(const Duration(seconds: 5),
          onTimeout: () {});
    } catch (e) {
      debugPrint('تعذّر بعض التهيئة (سيعمل التطبيق): $e');
    }

    // مهما حدث، علّم الحالة كجاهزة حتى لا يعلّق التطبيق
    ready = true;
    notifyListeners();

    // فحص الاتصال بالخلفية (بلا تعطيل)
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

  // إعداد لغات قسم الواتساب (مستقلة)
  void setVnSource(Language l) {
    vnSourceLang = l;
    notifyListeners();
  }

  void setVnTarget(Language l) {
    vnTargetLang = l;
    notifyListeners();
  }

  /// تُستدعى بعد كل ترجمة ناجحة لخصم رسالة من الرصيد المجاني
  Future<void> consumeMessage() async {
    if (subscribed) return; // المشتركون بلا حد
    usedMessages++;
    await _prefs.setInt(_kUsedKey, usedMessages);
    notifyListeners();
  }

  /// خصم ثوانٍ من تجربة الغرفة الصوتية المجانية (تُستدعى دورياً أثناء المكالمة)
  Future<void> consumeVoiceTrial(int seconds) async {
    if (subscribed) return; // المشتركون بلا حد
    voiceTrialUsed += seconds;
    await _prefs.setInt(_kVoiceTrialKey, voiceTrialUsed);
    notifyListeners();
  }

  /// خصم رسالة واتساب من التجربة المجانية (بعد ترجمة ناجحة)
  Future<void> consumeVoiceNote() async {
    if (subscribed) return;
    voiceNotesUsed++;
    await _prefs.setInt(_kVoiceNotesKey, voiceNotesUsed);
    notifyListeners();
  }

  /// يُستدعى عند تفعيل اشتراك — لمزامنته مع الخادم
  void Function(String plan)? onSubscribed;

  void _handlePurchase(String productId) {
    subscribed = true;
    currentPlan =
        productId.contains('yearly') ? PlanType.yearly : PlanType.monthly;
    _prefs.setBool(_kSubKey, true);
    _prefs.setString(
        _kSubTypeKey, currentPlan == PlanType.yearly ? 'yearly' : 'monthly');
    // زامن مع الخادم
    onSubscribed?.call(currentPlan == PlanType.yearly ? 'yearly' : 'monthly');
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
