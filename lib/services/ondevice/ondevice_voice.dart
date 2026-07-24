import 'package:flutter/foundation.dart';

import 'model_manager.dart';
import 'ondevice_llm_service.dart';
import 'ondevice_stt_service.dart';
import 'tts_engines.dart';

/// واجهة موحّدة لكل ما يعمل على الجهاز (الطبقة المجانية).
///
/// تُحقن ككائن واحد في الحالات (TranslationState / VoiceNoteState / RoomState).
///
/// القاعدة في كل التطبيق:
///   subscribed == true   → الخادم (Chatterbox على Modal + Groq)
///   subscribed == false  → هنا (على الهاتف، بلا تكلفة)
class OnDeviceVoice {
  OnDeviceVoice({bool enableLlmCleanup = false})
      : tts = TtsRouter(),
        stt = OnDeviceSttService(),
        llm = OnDeviceLlmService(enabled: enableLlmCleanup);

  /// موجّه متعدّد المحرّكات: Kokoro للغات التي يدعمها، Piper لما تبقّى.
  final TtsRouter tts;
  final OnDeviceSttService stt;
  final OnDeviceLlmService llm;

  /// نطق بصوت جاهز (بديل api.synthesize للمجاني).
  Future<String> speak({required String text, required String lang}) =>
      tts.speak(text: text, lang: lang);

  /// تفريغ + تنظيف (بديل api.transcribe للمجاني).
  Future<String> transcribe({required String path, required String lang}) async {
    final raw = await stt.transcribe(path: path, lang: lang);
    if (raw.isEmpty) return raw;
    return llm.refine(raw, lang);
  }

  bool supports(String lang) => tts.supports(lang);

  /// أي محرّك يخدم كل لغة (لعرضه في الإعدادات).
  Map<String, String> routingTable(Iterable<String> langs) =>
      tts.routingTable(langs);

  /// هل كل ما يلزم زوج اللغات منزّل؟
  Future<bool> isReadyFor(Iterable<String> langs) async {
    if (!await stt.isDownloaded()) return false;
    for (final l in langs) {
      if (!await tts.isDownloaded(l)) return false;
    }
    return true;
  }

  /// تنزيل مسبق لكل نماذج زوج اللغات.
  ///
  /// [onProgress] يُستدعى بـ (وصف، نسبة 0–1 أو null، الحالي، الإجمالي)
  Future<void> prefetch(
    Iterable<String> langs, {
    void Function(String label, double? fraction, int index, int total)?
        onProgress,
  }) async {
    final steps = <String, Future<void> Function(ProgressCb)>{
      'التفريغ (Whisper)': (cb) => stt.prefetch(onProgress: cb),
      for (final l in langs)
        'صوت $l (${tts.engineFor(l)?.id ?? '—'})': (cb) =>
            tts.prefetch(l, onProgress: cb),
    };

    var i = 0;
    for (final entry in steps.entries) {
      i++;
      final idx = i;
      await entry.value(
        (f) => onProgress?.call(entry.key, f, idx, steps.length),
      );
    }
    debugPrint('اكتمل تجهيز نماذج الجهاز (${steps.length} خطوات)');
  }

  Future<int> diskUsageBytes() => ModelManager.instance.diskUsageBytes();

  /// تفريغ كل المحرّكات من الذاكرة.
  void unloadAll() {
    tts.unloadAll();
    stt.unload();
  }

  void dispose() {
    tts.unloadAll();
    stt.dispose();
    llm.dispose();
  }
}
