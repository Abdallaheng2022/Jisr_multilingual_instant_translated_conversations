import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:uuid/uuid.dart';

import 'model_manager.dart';
import 'wav.dart';

/// ════════════════════════════════════════════════════════════════
///  معمارية متعدّدة المحرّكات (على غرار Voicebox)
///
///  الفكرة: لا يوجد "أفضل نموذج صغير" واحد — يوجد أفضل نموذج *لكل لغة*.
///  لذا نسجّل عدّة محرّكات، ويختار الموجّه الأفضل لكل لغة تلقائياً.
///
///    Kokoro-82M  → en, es, fr, hi  (جودة أعلى، 50+ صوتاً جاهزاً)
///    Piper VITS  → ar, tr, de      (المحرّك الصغير الوحيد الذي يغطيهما)
///
///  المشترك لا يمرّ من هنا إطلاقاً — يذهب إلى Chatterbox على Modal.
/// ════════════════════════════════════════════════════════════════

/// بروتوكول المحرّك — أضف محرّكاً جديداً بتنفيذ هذه الواجهة فقط.
abstract class TtsEngine {
  /// معرّف يُعرض في الإعدادات والسجلّات.
  String get id;

  /// اللغات التي يدعمها هذا المحرّك.
  Set<String> get languages;

  /// هل نُزّلت ملفات هذه اللغة؟
  Future<bool> isDownloaded(String lang);

  /// تنزيل مسبق (مع تقدّم).
  Future<void> prefetch(String lang, {ProgressCb? onProgress});

  /// توليد صوت — يعيد مسار WAV محلي.
  Future<String> speak({
    required String text,
    required String lang,
    double speed = 1.0,
    ProgressCb? onDownloadProgress,
  });

  /// تفريغ من الذاكرة (يبقي الملفات على القرص) — كـ per-model unload في Voicebox.
  void unload();
}

// ════════════════════════════════════════════════════════════════
//  المحرّك 1 — Piper (VITS)
//  التغطية الأوسع بين النماذج الصغيرة: ar / tr / de وأكثر من 40 لغة.
//  ~30–80MB للصوت، RTF ≈ 0.3× على هاتف متوسط، ذاكرة ≈ 80MB.
// ════════════════════════════════════════════════════════════════
class PiperEngine extends _SherpaEngineBase implements TtsEngine {
  @override
  String get id => 'piper';

  @override
  Set<String> get languages => OnDeviceModels.piper.keys.toSet();

  @override
  ModelSpec? specFor(String lang) => OnDeviceModels.piper[lang];

  @override
  sherpa.OfflineTtsModelConfig buildConfig(String root, String lang) =>
      sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: '$root/model.onnx',
          tokens: '$root/tokens.txt',
          dataDir: '$root/espeak-ng-data',
        ),
        numThreads: 2,
        provider: 'cpu',
      );

  @override
  int sidFor(String lang) => 0; // أصوات Piper أحادية المتحدّث
}

// ════════════════════════════════════════════════════════════════
//  المحرّك 2 — Kokoro-82M
//  جودة أعلى محسوسة من Piper بنفس فئة الحجم (StyleTTS2)، لكن
//  لا يدعم العربية ولا التركية — لذا يُستخدم للغات التي يغطيها فقط.
//  نموذج واحد يخدم عدّة لغات (بدل ملف لكل لغة في Piper).
// ════════════════════════════════════════════════════════════════
class KokoroEngine extends _SherpaEngineBase implements TtsEngine {
  @override
  String get id => 'kokoro';

  @override
  Set<String> get languages => OnDeviceModels.kokoroVoices.keys.toSet();

  @override
  ModelSpec? specFor(String lang) =>
      languages.contains(lang) ? OnDeviceModels.kokoro : null;

  @override
  sherpa.OfflineTtsModelConfig buildConfig(String root, String lang) =>
      sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: '$root/model.onnx',
          voices: '$root/voices.bin',
          tokens: '$root/tokens.txt',
          dataDir: '$root/espeak-ng-data',
        ),
        numThreads: 2,
        provider: 'cpu',
      );

  /// Kokoro متعدّد المتحدّثين — لكل لغة صوت مناسب (تحقّق من قائمة الأصوات).
  @override
  int sidFor(String lang) => OnDeviceModels.kokoroVoices[lang] ?? 0;

  /// نموذج واحد لكل اللغات → إن نُزّل للغة فقد نُزّل للجميع.
  @override
  String cacheKeyFor(String lang) => 'kokoro';
}

// ════════════════════════════════════════════════════════════════
//  قاعدة مشتركة لمحرّكات sherpa-onnx
// ════════════════════════════════════════════════════════════════
abstract class _SherpaEngineBase {
  static const _uuid = Uuid();
  static bool _bindingsReady = false;

  sherpa.OfflineTts? _tts;
  String? _loadedKey;

  ModelSpec? specFor(String lang);
  sherpa.OfflineTtsModelConfig buildConfig(String root, String lang);
  int sidFor(String lang);

  /// مفتاح التخزين المؤقّت — افتراضياً نموذج لكل لغة.
  String cacheKeyFor(String lang) => lang;

  Future<bool> isDownloaded(String lang) async {
    final spec = specFor(lang);
    if (spec == null) return false;
    return ModelManager.instance.isReady(spec);
  }

  Future<void> prefetch(String lang, {ProgressCb? onProgress}) async {
    final spec = specFor(lang);
    if (spec == null) return;
    await ModelManager.instance.ensure(spec, onProgress: onProgress);
  }

  Future<String> speak({
    required String text,
    required String lang,
    double speed = 1.0,
    ProgressCb? onDownloadProgress,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) throw TtsEngineException('نص فارغ');

    final tts = await _engine(lang, onDownloadProgress);
    final audio = tts.generate(text: clean, sid: sidFor(lang), speed: speed);

    final bytes = encodeWavPcm16(audio.samples, audio.sampleRate);
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/ondev_${_uuid.v4()}.wav';
    await File(out).writeAsBytes(bytes, flush: true);
    return out;
  }

  Future<sherpa.OfflineTts> _engine(String lang, ProgressCb? onProgress) async {
    final key = cacheKeyFor(lang);
    if (_tts != null && _loadedKey == key) return _tts!;

    final spec = specFor(lang);
    if (spec == null) {
      throw TtsEngineException('اللغة "$lang" غير مدعومة في هذا المحرّك');
    }

    if (!_bindingsReady) {
      sherpa.initBindings();
      _bindingsReady = true;
    }

    // محرّك واحد فقط في الذاكرة — فرّغ السابق قبل تحميل الجديد
    _tts?.free();
    _tts = null;
    _loadedKey = null;

    final root = await ModelManager.instance.ensure(spec, onProgress: onProgress);
    final config = sherpa.OfflineTtsConfig(
      model: buildConfig(root, lang),
      maxNumSentences: 2,
    );

    _loadedKey = key;
    return _tts = sherpa.OfflineTts(config);
  }

  void unload() {
    _tts?.free();
    _tts = null;
    _loadedKey = null;
  }
}

// ════════════════════════════════════════════════════════════════
//  الموجّه — يختار أفضل محرّك لكل لغة
// ════════════════════════════════════════════════════════════════
class TtsRouter {
  TtsRouter({List<TtsEngine>? engines})
      : engines = engines ?? [KokoroEngine(), PiperEngine()];

  /// مُرتّبة حسب الأفضلية: الأول الذي يدعم اللغة يفوز.
  /// Kokoro أولاً (جودة أعلى)، ثم Piper (تغطية أوسع).
  final List<TtsEngine> engines;

  /// تجاوز يدوي من الإعدادات: {'en': 'piper'} يجبر الإنجليزية على Piper.
  final Map<String, String> overrides = {};

  TtsEngine? engineFor(String lang) {
    final forced = overrides[lang];
    if (forced != null) {
      for (final e in engines) {
        if (e.id == forced && e.languages.contains(lang)) return e;
      }
    }
    for (final e in engines) {
      if (e.languages.contains(lang)) return e;
    }
    return null;
  }

  bool supports(String lang) => engineFor(lang) != null;

  Future<String> speak({
    required String text,
    required String lang,
    double speed = 1.0,
    ProgressCb? onDownloadProgress,
  }) async {
    final engine = engineFor(lang);
    if (engine == null) {
      throw TtsEngineException('لا يوجد محرّك على الجهاز يدعم اللغة: $lang');
    }
    debugPrint('TTS[$lang] → ${engine.id}');
    return engine.speak(
      text: text,
      lang: lang,
      speed: speed,
      onDownloadProgress: onDownloadProgress,
    );
  }

  Future<bool> isDownloaded(String lang) async {
    final e = engineFor(lang);
    return e == null ? false : e.isDownloaded(lang);
  }

  Future<void> prefetch(String lang, {ProgressCb? onProgress}) async {
    await engineFor(lang)?.prefetch(lang, onProgress: onProgress);
  }

  /// يفرّغ كل المحرّكات (ضغط ذاكرة / خروج).
  void unloadAll() {
    for (final e in engines) {
      e.unload();
    }
  }

  /// خريطة لغة → محرّك (لعرضها في الإعدادات، كجدول المحرّكات في Voicebox).
  Map<String, String> routingTable(Iterable<String> langs) => {
        for (final l in langs) l: engineFor(l)?.id ?? '—',
      };
}

class TtsEngineException implements Exception {
  final String message;
  TtsEngineException(this.message);
  @override
  String toString() => message;
}
