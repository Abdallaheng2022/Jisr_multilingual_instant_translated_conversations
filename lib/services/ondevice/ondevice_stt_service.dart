import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_manager.dart';
import 'wav.dart';

/// التفريغ الصوتي على الجهاز (الطبقة المجانية) — Whisper عبر sherpa-onnx.
///
///   • المستخدم المجاني  → هذه الخدمة (بلا خادم، بلا حصّة Groq)
///   • المشترك           → api.transcribe() على Groq whisper-large-v3
///
/// المدخل: ملف WAV بصيغة PCM 16-bit (وهو ما يسجّله AudioService أصلاً).
class OnDeviceSttService {
  bool _bindingsReady = false;
  sherpa.OfflineRecognizer? _rec;
  String? _loadedLang;

  Future<bool> isDownloaded() =>
      ModelManager.instance.isReady(OnDeviceModels.whisper);

  Future<void> prefetch({ProgressCb? onProgress}) async {
    await ModelManager.instance
        .ensure(OnDeviceModels.whisper, onProgress: onProgress);
  }

  /// يفرّغ ملفاً صوتياً ويعيد النص.
  /// [lang] رمز اللغة (مثل 'ar')، أو '' للكشف التلقائي.
  Future<String> transcribe({
    required String path,
    required String lang,
    ProgressCb? onDownloadProgress,
  }) async {
    final rec = await _ensure(lang, onDownloadProgress: onDownloadProgress);
    final wav = readWavPcm16(path);

    final stream = rec.createStream();
    try {
      stream.acceptWaveform(samples: wav.samples, sampleRate: wav.sampleRate);
      rec.decode(stream);
      return rec.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  Future<sherpa.OfflineRecognizer> _ensure(
    String lang, {
    ProgressCb? onDownloadProgress,
  }) async {
    if (_rec != null && _loadedLang == lang) return _rec!;

    if (!_bindingsReady) {
      sherpa.initBindings();
      _bindingsReady = true;
    }

    // تغيّرت اللغة → أعد البناء (Whisper يأخذ اللغة في الإعداد)
    _rec?.free();
    _rec = null;
    _loadedLang = null;

    final dir = await ModelManager.instance
        .ensure(OnDeviceModels.whisper, onProgress: onDownloadProgress);

    // بادئة اسم الملف تتبع حجم النموذج (base / small / …)
    final prefix = OnDeviceModels.whisper.id.split('-').last; // 'base'

    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: '$dir/$prefix-encoder.onnx',
          decoder: '$dir/$prefix-decoder.onnx',
          language: lang, // '' = كشف تلقائي
          task: 'transcribe',
        ),
        tokens: '$dir/$prefix-tokens.txt',
        modelType: 'whisper',
        numThreads: 2,
        provider: 'cpu',
      ),
    );

    _loadedLang = lang;
    return _rec = sherpa.OfflineRecognizer(config);
  }

  void unload() {
    _rec?.free();
    _rec = null;
    _loadedLang = null;
  }

  void dispose() => unload();
}
