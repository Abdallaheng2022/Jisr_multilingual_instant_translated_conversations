import 'dart:io';

/// بصمة صوتية (5 ثوانٍ) تُستخدم كمرجع للاستنساخ.
/// مع تعهّد المستخدم أن الصوت له (بدل التحقق التقني المعقّد).
class VoiceFingerprint {
  final String path; // مسار ملف البصمة
  final double duration; // المدة الفعلية
  final DateTime recordedAt;
  final bool ownershipConfirmed; // تعهّد المستخدم أن الصوت له

  const VoiceFingerprint({
    required this.path,
    required this.duration,
    required this.recordedAt,
    required this.ownershipConfirmed,
  });

  bool get isValid => ownershipConfirmed && File(path).existsSync();
}

/// فحص جودة البصمة الصوتية (بسيط — يتأكد أنها ليست صامتة/قصيرة).
class FingerprintQuality {
  FingerprintQuality._();

  static const double minDuration = 3.0; // على الأقل 3 ثوانٍ
  static const double targetDuration = 5.0; // المستهدف 5 ثوانٍ
  static const int minSizeBytes = 8000; // حجم أدنى (يكشف الصامت/التالف)

  /// يفحص ملف البصمة، يعيد نتيجة مع رسالة.
  static FingerprintResult check(String path, double duration) {
    final file = File(path);
    if (!file.existsSync()) {
      return FingerprintResult(false, 'لم يُسجّل الصوت');
    }
    final size = file.lengthSync();
    if (duration < minDuration) {
      return FingerprintResult(
          false, 'التسجيل قصير جداً — تحدّث ${targetDuration.toInt()} ثوانٍ');
    }
    if (size < minSizeBytes) {
      return FingerprintResult(
          false, 'الصوت غير واضح — سجّل في مكان هادئ');
    }
    return FingerprintResult(true, 'بصمة صوتية جيدة');
  }
}

class FingerprintResult {
  final bool ok;
  final String message;
  const FingerprintResult(this.ok, this.message);
}

/// طرق إدخال المحتوى في قسم الترجمة الصوتية
enum InputMethod {
  whatsappShare, // مشاركة صوت من واتساب
  record, // تسجيل مباشر في التطبيق
  text, // كتابة النص
}

extension InputMethodX on InputMethod {
  String get label => switch (this) {
        InputMethod.whatsappShare => 'صوت من واتساب',
        InputMethod.record => 'سجّل صوتك',
        InputMethod.text => 'اكتب النص',
      };
}
