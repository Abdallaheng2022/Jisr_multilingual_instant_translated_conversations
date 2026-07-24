import 'dart:async';

import 'package:flutter/foundation.dart';

import 'model_manager.dart';

/// تنظيف النص المُفرّغ على الجهاز — Qwen3-0.6B (اختياري).
///
/// ⚠️ مُعطّل افتراضياً. السبب: 0.6B على هاتف متوسط يضيف 3–10 ثوانٍ لكل ترجمة،
/// وهي كلفة UX كبيرة في الطبقة المجانية. فعّله فقط بعد قياس السرعة على جهازك.
///
/// عند التعطيل يعيد النص كما هو — فالتطبيق يعمل بالكامل بدونه.
///
/// للتفعيل:
///   1) أضف حزمة llama.cpp لـ Flutter (مثل fllama) إلى pubspec.yaml
///   2) نفّذ [_infer] أدناه بواجهة تلك الحزمة
///   3) مرّر enabled: true عند الإنشاء
class OnDeviceLlmService {
  OnDeviceLlmService({this.enabled = false});

  /// شغّل/أوقف التنظيف بالكامل.
  final bool enabled;

  String? _modelPath;

  Future<bool> isDownloaded() =>
      ModelManager.instance.isReady(OnDeviceModels.qwenCleanup);

  Future<void> prefetch({ProgressCb? onProgress}) async {
    if (!enabled) return;
    _modelPath = await ModelManager.instance
        .ensure(OnDeviceModels.qwenCleanup, onProgress: onProgress);
  }

  /// ينظّف نصاً مُفرّغاً (تلعثم، تكرار، كلمات زائدة).
  /// يعيد النص الأصلي عند أي فشل — لا يوقف خط الترجمة أبداً.
  Future<String> refine(String text, String lang) async {
    if (!enabled) return text;
    final input = text.trim();
    if (input.length < 12) return text; // قصير جداً — لا فائدة

    try {
      _modelPath ??=
          await ModelManager.instance.ensure(OnDeviceModels.qwenCleanup);
      final out = (await _infer(_prompt(input, lang))).trim();
      // حارس: إن خرج النموذج عن السياق (طوّل كثيراً) تجاهله
      if (out.isEmpty || out.length > input.length * 2) return text;
      return out;
    } catch (e) {
      debugPrint('تعذّر تنظيف النص (سيُستخدم الأصل): $e');
      return text;
    }
  }

  String _prompt(String text, String lang) =>
      'صحّح الإملاء وأزل التلعثم والتكرار والكلمات الزائدة من هذا النص '
      'المُفرّغ من الصوت، دون تغيير المعنى ودون إضافة أي شرح. '
      'أعد النص المنظّف فقط:\n\n$text';

  // ============================================================
  //  نقطة التبديل الوحيدة — نفّذها بمكتبة llama.cpp التي تختارها
  // ============================================================
  //
  //  مثال بـ fllama (تحقّق من توقيع الـ callback في نسختك — يختلف بين
  //  الإصدارات بين (response, done) و (response, json, done)):
  //
  //    final done = Completer<String>();
  //    var latest = '';
  //    fllamaChat(
  //      OpenAiRequest(
  //        maxTokens: 256,
  //        messages: [
  //          Message(Role.system, 'أنت مدقّق لغوي. تعيد النص منظّفاً فقط.'),
  //          Message(Role.user, prompt),
  //        ],
  //        modelPath: _modelPath!,
  //        numGpuLayers: 0,
  //        temperature: 0.2,
  //        topP: 0.9,
  //        contextSize: 1024,
  //      ),
  //      (response, isDone) {
  //        latest = response;
  //        if (isDone && !done.isCompleted) done.complete(latest);
  //      },
  //    );
  //    return done.future.timeout(const Duration(seconds: 30));
  //
  Future<String> _infer(String prompt) async {
    throw UnimplementedError(
      'تنظيف النص غير مُنفّذ — أضف مكتبة llama.cpp ونفّذ _infer، '
      'أو أبقِ enabled: false.',
    );
  }

  void dispose() {}
}
