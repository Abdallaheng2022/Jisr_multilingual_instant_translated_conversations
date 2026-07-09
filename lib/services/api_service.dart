import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// عميل يتصل بسيرفر Modal مباشرة (REST/JSON بسيط).
///
/// نقاط النهاية:
///   POST /health     → فحص
///   POST /translate  → {text, from, to} → {ok, translated}
///   POST /stt        → {audio(base64), lang} → {ok, text}
///   POST /tts        → {text, lang, voice?(base64)} → {ok, audio(base64)}
///
/// أبسط بكثير من Gradio — طلب JSON واحد لكل خدمة، بلا خطوتين ولا SSE.
class ApiService {
  ApiService({required this.baseUrl});

  /// رابط سيرفر Modal، مثل: https://USERNAME--jisr-fastapi-app.modal.run
  final String baseUrl;

  static const _uuid = Uuid();
  final _client = http.Client();

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final res = await _client
        .post(
          _u(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      // حاول قراءة رسالة الخطأ من الجسم
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw ApiException(err['error']?.toString() ?? 'HTTP ${res.statusCode}');
      } catch (_) {
        throw ApiException('HTTP ${res.statusCode}');
      }
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ============================================================
  //  فحص الاتصال
  // ============================================================
  Future<HealthStatus> checkHealth() async {
    try {
      final res = await _client
          .post(_u('/health'),
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
  //  ترجمة
  // ============================================================
  Future<String> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    if (from == to) return text;
    final data = await _post('/translate',
        {'text': text, 'from': from, 'to': to},
        timeout: const Duration(seconds: 60));
    if (data['ok'] != true) {
      throw ApiException(data['error']?.toString() ?? 'فشلت الترجمة');
    }
    return (data['translated'] as String?)?.trim() ?? text;
  }

  // ============================================================
  //  تفريغ صوتي
  // ============================================================
  Future<String> transcribe({
    required String path,
    required String lang,
  }) async {
    final bytes = await File(path).readAsBytes();
    final audioB64 = base64Encode(bytes);
    final data = await _post('/stt',
        {'audio': audioB64, 'lang': lang},
        timeout: const Duration(seconds: 120));
    if (data['ok'] != true) {
      throw ApiException(data['error']?.toString() ?? 'فشل التفريغ');
    }
    return (data['text'] as String?)?.trim() ?? '';
  }

  // ============================================================
  //  توليد صوت مستنسخ (يعيد مسار ملف محلي)
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
    final data = await _post(
      '/tts',
      {
        'text': text,
        'lang': lang,
        if (voiceB64 != null) 'voice': voiceB64,
      },
      timeout: const Duration(seconds: 180),
    );
    if (data['ok'] != true || data['audio'] == null) {
      throw ApiException(data['error']?.toString() ?? 'فشل توليد الصوت');
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
