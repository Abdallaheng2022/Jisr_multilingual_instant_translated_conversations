import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// نوع حزمة النموذج.
enum ModelKind {
  /// أرشيف sherpa-onnx (.tar.bz2) — يُفكّ إلى مجلّد (Piper / Whisper).
  sherpaTarBz2,

  /// ملف GGUF خام — يُنزَّل كما هو (نموذج LLM).
  ggufRaw,
}

/// وصف نموذج قابل للتنزيل.
class ModelSpec {
  /// معرّف فريد — يجب أن يطابق اسم المجلّد داخل الأرشيف (لنماذج sherpa).
  final String id;
  final String url;
  final ModelKind kind;

  /// ملف نتحقّق من وجوده لاعتبار النموذج "جاهزاً".
  final String? sentinelFile;

  const ModelSpec({
    required this.id,
    required this.url,
    required this.kind,
    this.sentinelFile,
  });
}

/// تقدّم التنزيل (0.0–1.0)، أو null إن كان الحجم مجهولاً.
typedef ProgressCb = void Function(double? fraction);

/// يدير تنزيل وتخزين نماذج الجهاز (TTS / STT / LLM) في مكان واحد.
///
/// النماذج كبيرة (Piper ~60–90MB، Whisper ~40–240MB، Qwen3-0.6B ~0.5GB)،
/// لذا لا تُحزَم داخل APK — تُنزَّل عند أول استخدام إلى تخزين التطبيق.
class ModelManager {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  Directory? _rootCache;

  /// الجذر: <appSupport>/ondevice_models/
  Future<Directory> _root() async {
    if (_rootCache != null) return _rootCache!;
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/ondevice_models');
    if (!await root.exists()) await root.create(recursive: true);
    return _rootCache = root;
  }

  /// هل النموذج جاهز على القرص؟
  Future<bool> isReady(ModelSpec spec) async {
    final root = await _root();
    if (spec.kind == ModelKind.ggufRaw) {
      return File('${root.path}/${spec.id}').exists();
    }
    final dir = Directory('${root.path}/${spec.id}');
    if (!await dir.exists()) return false;
    if (spec.sentinelFile == null) return true;
    return File('${dir.path}/${spec.sentinelFile}').exists();
  }

  /// حجم ما نُزّل فعلياً (لعرضه في شاشة الإعدادات).
  Future<int> diskUsageBytes() async {
    final root = await _root();
    var total = 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// يحذف نموذجاً من القرص (لتحرير مساحة).
  Future<void> delete(ModelSpec spec) async {
    final root = await _root();
    final path = '${root.path}/${spec.id}';
    if (spec.kind == ModelKind.ggufRaw) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } else {
      final d = Directory(path);
      if (await d.exists()) await d.delete(recursive: true);
    }
  }

  /// المسار الجاهز للنموذج (مجلّد للأرشيف، ملف لـ GGUF).
  /// يُنزّل ويفكّ عند أول استدعاء إن لزم.
  Future<String> ensure(ModelSpec spec, {ProgressCb? onProgress}) async {
    final root = await _root();
    final target = '${root.path}/${spec.id}';
    if (await isReady(spec)) return target;

    if (spec.kind == ModelKind.ggufRaw) {
      await _download(spec.url, target, onProgress);
      return target;
    }

    // نزّل الأرشيف مؤقتاً ثم فكّه
    final tmp = '$target.tar.bz2';
    await _download(spec.url, tmp, onProgress);
    await _extractTarBz2(tmp, root.path);
    try {
      await File(tmp).delete();
    } catch (_) {}

    if (!await Directory(target).exists()) {
      throw ModelException(
        'فُكّ الأرشيف لكن المجلّد "${spec.id}" غير موجود — '
        'تأكد أن id يطابق اسم المجلّد داخل الأرشيف.',
      );
    }
    return target;
  }

  // ============================================================
  //  تنزيل متدفّق إلى ملف (مع تقدّم)
  // ============================================================
  Future<void> _download(String url, String outPath, ProgressCb? onProgress) async {
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(minutes: 10));
      if (res.statusCode != 200) {
        throw ModelException('فشل التنزيل (HTTP ${res.statusCode}) — $url');
      }

      final total = res.contentLength; // قد يكون null
      var received = 0;
      final tmpPart = File('$outPath.part');
      await tmpPart.parent.create(recursive: true);
      final sink = tmpPart.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total != null && total > 0 ? received / total : null);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      // إعادة التسمية ذرّية — يمنع اعتبار تنزيل ناقص "جاهزاً"
      await tmpPart.rename(outPath);
    } finally {
      client.close();
    }
  }

  // ============================================================
  //  فكّ .tar.bz2 (صيغة نماذج sherpa-onnx)
  // ============================================================
  Future<void> _extractTarBz2(String archivePath, String destDir) async {
    final bytes = await File(archivePath).readAsBytes();
    final tarBytes = const BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final entry in archive) {
      final outPath = '$destDir/${entry.name}';
      if (entry.isFile) {
        final f = File(outPath);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.content as List<int>, flush: true);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    debugPrint('فُكّ الأرشيف: $archivePath');
  }
}

class ModelException implements Exception {
  final String message;
  ModelException(this.message);
  @override
  String toString() => message;
}

// ============================================================
//  سجلّ النماذج
// ============================================================
//
//  نماذج sherpa الرسمية:  https://github.com/k2-fsa/sherpa-onnx/releases
//  نماذج Qwen3 GGUF:      https://huggingface.co/Qwen/Qwen3-0.6B-GGUF
//
//  مهم: تحقّق من أسماء الملفات/الروابط قبل الإطلاق — قد تتغيّر الإصدارات.
//  id يجب أن يطابق اسم المجلّد داخل الأرشيف بالضبط.
class OnDeviceModels {
  OnDeviceModels._();

  static const _ttsBase =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';
  static const _asrBase =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';

  /// أصوات Piper لكل لغة (الطبقة المجانية).
  /// Piper يغطي لغاتك السبع — بما فيها ar / tr اللتان لا يدعمهما Kokoro.
  static const piper = <String, ModelSpec>{
    'ar': ModelSpec(
        id: 'vits-piper-ar_JO-kareem-medium',
        url: '$_ttsBase/vits-piper-ar_JO-kareem-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'tr': ModelSpec(
        id: 'vits-piper-tr_TR-dfki-medium',
        url: '$_ttsBase/vits-piper-tr_TR-dfki-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'de': ModelSpec(
        id: 'vits-piper-de_DE-thorsten-medium',
        url: '$_ttsBase/vits-piper-de_DE-thorsten-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'en': ModelSpec(
        id: 'vits-piper-en_US-amy-medium',
        url: '$_ttsBase/vits-piper-en_US-amy-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'fr': ModelSpec(
        id: 'vits-piper-fr_FR-siwis-medium',
        url: '$_ttsBase/vits-piper-fr_FR-siwis-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'es': ModelSpec(
        id: 'vits-piper-es_ES-davefx-medium',
        url: '$_ttsBase/vits-piper-es_ES-davefx-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
    'hi': ModelSpec(
        id: 'vits-piper-hi_IN-pratham-medium',
        url: '$_ttsBase/vits-piper-hi_IN-pratham-medium.tar.bz2',
        kind: ModelKind.sherpaTarBz2,
        sentinelFile: 'model.onnx'),
  };

  /// ── Kokoro-82M ──────────────────────────────────────────────
  /// نموذج واحد يغطي عدّة لغات بجودة أعلى من Piper في نفس فئة الحجم.
  /// لا يدعم العربية ولا التركية — لذا يبقى Piper ضرورياً لهما.
  static const kokoro = ModelSpec(
      id: 'kokoro-multi-lang-v1_0',
      url: '$_ttsBase/kokoro-multi-lang-v1_0.tar.bz2',
      kind: ModelKind.sherpaTarBz2,
      sentinelFile: 'model.onnx');

  /// لغة → رقم المتحدّث (sid) داخل Kokoro.
  ///
  /// ⚠️ تحقّق من هذه الأرقام قبل الإطلاق: sid خاطئ = صوت إنجليزي يقرأ نصاً
  /// إسبانياً. افتح ملف الأصوات المرفق بالنموذج (voices / VOICES.md) وطابق
  /// الاسم بالرقم، أو استخدم شاشة اختبار تنطق جملة بكل sid مرشّح.
  static const kokoroVoices = <String, int>{
    'en': 0,
    'es': 0,
    'fr': 0,
    'hi': 0,
  };

  /// Whisper متعدّد اللغات للتفريغ على الجهاز.
  static const whisperBase = ModelSpec(
      id: 'sherpa-onnx-whisper-base',
      url: '$_asrBase/sherpa-onnx-whisper-base.tar.bz2',
      kind: ModelKind.sherpaTarBz2,
      sentinelFile: 'base-encoder.onnx');

  static const whisperSmall = ModelSpec(
      id: 'sherpa-onnx-whisper-small',
      url: '$_asrBase/sherpa-onnx-whisper-small.tar.bz2',
      kind: ModelKind.sherpaTarBz2,
      sentinelFile: 'small-encoder.onnx');

  /// النموذج المستخدم فعلياً للتفريغ المجاني (بدّله إلى whisperSmall للجودة).
  static const whisper = whisperBase;

  /// Qwen3-0.6B لتنظيف النص (GGUF مكمّم Q4_K_M ≈ 0.5GB).
  static const qwenCleanup = ModelSpec(
      id: 'qwen3-0.6b-q4_k_m.gguf',
      url:
          'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf',
      kind: ModelKind.ggufRaw);

}
