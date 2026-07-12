import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// عميل جسر — تصميم موزّع:
///   • الاستنساخ (TTS)  → سيرفر Modal (يحتاج GPU)
///   • التفريغ (STT)    → Groq مباشرة (مجاني، سريع جداً)
///   • الترجمة          → MyMemory مباشرة (مجاني، بلا سيرفر)
///
/// التطبيق يتصل بكل خدمة في مكانها الأنسب — أقل اعتماد على سيرفر واحد.
class ApiService {
  ApiService({
    required this.modalUrl,
    this.groqKey = _defaultGroqKey,
  });

  /// رابط سيرفر Modal (للاستنساخ)، مثل:
  ///   https://USERNAME--jisr-fastapi-app.modal.run
  final String modalUrl;

  /// مفتاح Groq (للتفريغ). مجاني من https://console.groq.com
  final String groqKey;

  // ضع مفتاح Groq هنا افتراضياً، أو مرّره عبر --dart-define=GROQ_KEY=...
  static const _defaultGroqKey =
      String.fromEnvironment('GROQ_KEY', defaultValue: '');

  static const _uuid = Uuid();
  final _client = http.Client();

  // ============================================================
  //  فحص الاتصال (يفحص سيرفر Modal)
  // ============================================================
  Future<HealthStatus> checkHealth() async {
    try {
      final res = await _client
          .post(Uri.parse('$modalUrl/health'),
              headers: {'Content-Type': 'application/json'}, body: '{}')
          .timeout(const Duration(seconds: 30));
      return res.statusCode == 200
          ? HealthStatus.connected
          : HealthStatus.sleeping;
    } catch (_) {
      return HealthStatus.offline;
    }
  }

  // ============================================================
  //  الترجمة — MyMemory API مباشرة (مجاني، بلا سيرفر)
  // ============================================================
  Future<String> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    if (from == to) return text;
    final q = Uri.encodeComponent(text);
    final url =
        'https://api.mymemory.translated.net/get?q=$q&langpair=$from|$to';
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException('فشلت الترجمة (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final translated =
        (data['responseData']?['translatedText'] as String?)?.trim();
    if (translated == null || translated.isEmpty) {
      throw ApiException('لم تُرجع الترجمة نتيجة');
    }
    return translated;
  }

  // ============================================================
  //  التفريغ — Groq Whisper مباشرة (مجاني، سريع)
  // ============================================================
  Future<String> transcribe({
    required String path,
    required String lang,
    String? prompt, // تلميح يوجّه النموذج (مفيد مع اللهجات)
  }) async {
    if (groqKey.isEmpty) {
      throw ApiException(
          'مفتاح Groq غير مضبوط. احصل عليه مجاناً من console.groq.com');
    }
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    req.headers['Authorization'] = 'Bearer $groqKey';
    // النموذج الكامل — أدق مع اللهجات العامية (turbo أسرع لكن أقل دقة)
    req.fields['model'] = 'whisper-large-v3';
    if (lang.isNotEmpty) req.fields['language'] = lang;

    // تلميح للنموذج: يحسّن فهم اللهجات العامية
    final hint = prompt ?? _dialectHint(lang);
    if (hint.isNotEmpty) req.fields['prompt'] = hint;

    // temperature=0 → أكثر التزاماً بالصوت، أقل "تخمين"
    req.fields['temperature'] = '0';

    req.files.add(await http.MultipartFile.fromPath('file', path));

    final streamed =
        await _client.send(req).timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw ApiException('فشل التفريغ (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['text'] as String?)?.trim() ?? '';
  }

  /// تلميح يخبر النموذج أن الكلام قد يكون بلهجة عامية
  String _dialectHint(String lang) {
    switch (lang) {
      case 'ar':
        return 'كلام بالعامية العربية، لهجة يومية دارجة.';
      case 'tr':
        return 'Günlük konuşma dili.';
      case 'es':
        return 'Habla coloquial cotidiana.';
      case 'hi':
        return 'रोज़मर्रा की बोलचाल।';
      default:
        return '';
    }
  }

  // ============================================================
  //  الاستنساخ — سيرفر Modal (يعيد مسار ملف محلي)
  // ============================================================
  Future<String> synthesize({
    required String text,
    required String lang,
    String? refAudioPath,
  }) async {
    String? voiceB64;
    if (refAudioPath != null && File(refAudioPath).existsSync()) {
      voiceB64 = base64Encode(await File(refAudioPath).readAsBytes());
    }
    final res = await _client
        .post(
          Uri.parse('$modalUrl/tts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'lang': lang,
            if (voiceB64 != null) 'voice': voiceB64,
          }),
        )
        .timeout(const Duration(seconds: 180));
    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw ApiException(err['error']?.toString() ?? 'HTTP ${res.statusCode}');
      } catch (_) {
        throw ApiException('فشل توليد الصوت (HTTP ${res.statusCode})');
      }
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true || data['audio'] == null) {
      throw ApiException(data['error']?.toString() ?? 'لم يُرجع الخادم صوتاً');
    }
    final audioBytes = base64Decode(data['audio'] as String);
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/tts_${_uuid.v4()}.wav';
    await File(outPath).writeAsBytes(audioBytes, flush: true);
    return outPath;
  }

  void dispose() => _client.close();
}

enum HealthStatus {
  connected,
  sleeping,
  notConfigured,
  offline;

  String get label => switch (this) {
        HealthStatus.connected => 'متصل',
        HealthStatus.sleeping => 'الخادم يستيقظ…',
        HealthStatus.notConfigured => 'الخادم غير مضبوط',
        HealthStatus.offline => 'لا يوجد اتصال',
      };

  bool get isReady => this == HealthStatus.connected;
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
