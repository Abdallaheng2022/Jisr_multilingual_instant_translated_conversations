import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// عميل الشبكة — يتصل بالسيرفر الوسيط (api-server.js) الذي يمرّر لـ Chatterbox.
///
/// العقود (نفس ما يوفّره api-server.js):
///   GET  /api/health                     → {backend_url_set, backend_ok}
///   POST /api/translate                  → {ok, translated}
///   POST /api/voice/tts?encoding=base64  → {ok, audio(base64), format}
class ApiService {
  ApiService({required this.baseUrl});

  /// عنوان السيرفر الوسيط. غيّره لعنوانك عند النشر.
  final String baseUrl;

  static const _uuid = Uuid();
  final _client = http.Client();

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// فحص اتصال السيرفر والـ Space
  Future<HealthStatus> checkHealth() async {
    try {
      final res = await _client
          .get(_u('/api/health'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return HealthStatus.offline;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final urlSet = data['backend_url_set'] == true;
      final ok = data['backend_ok'] == true;
      if (urlSet && ok) return HealthStatus.connected;
      if (urlSet) return HealthStatus.sleeping; // GPU نايم
      return HealthStatus.notConfigured;
    } catch (_) {
      return HealthStatus.offline;
    }
  }

  /// ترجمة نص من لغة إلى أخرى
  Future<String> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    final res = await _client
        .post(
          _u('/api/translate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'from': from, 'to': to}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException('فشلت الترجمة (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true || data['translated'] == null) {
      throw ApiException('لم تُرجع الترجمة نتيجة');
    }
    return data['translated'] as String;
  }

  /// تفريغ صوتي (STT): يرفع ملف الصوت المسجّل ويعيد النص.
  /// يمرّره السيرفر الوسيط لخدمة تفريغ (مثل Whisper / ElevenLabs Scribe).
  Future<String> transcribe({
    required String path,
    required String lang,
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/voice/stt'));
    req.fields['lang'] = lang;
    req.files.add(await http.MultipartFile.fromPath('audio', path));
    final streamed =
        await _client.send(req).timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw ApiException('فشل التفريغ الصوتي (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw ApiException('لم يُرجع التفريغ نتيجة');
    }
    return (data['text'] as String?)?.trim() ?? '';
  }

  /// تحويل نص إلى كلام بصوت مستنسخ، وحفظه كملف محلي. يعيد مسار الملف.
  ///
  /// [lang] لغة النص المُخرَج. [refAudioPath] ملف صوت مرجعي اختياري لاستنساخه
  /// (صوت المستخدم نفسه) — إن تُرك null يستخدم السيرفر الصوت الافتراضي.
  Future<String> synthesize({
    required String text,
    required String lang,
    String? refAudioPath,
  }) async {
    // نستخدم مسار base64 لأنه الأنسب للموبايل (نحفظ الملف مباشرة)
    String? refB64;
    if (refAudioPath != null && File(refAudioPath).existsSync()) {
      refB64 = base64Encode(await File(refAudioPath).readAsBytes());
    }

    final res = await _client
        .post(
          _u('/api/voice/tts?encoding=base64'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'lang': lang,
            if (refB64 != null) 'voiceRef': refB64,
          }),
        )
        .timeout(const Duration(seconds: 180)); // أول طلب قد يوقظ الـ Space

    if (res.statusCode != 200) {
      throw ApiException('فشل توليد الصوت (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true || data['audio'] == null) {
      throw ApiException('لم يُرجع السيرفر صوتاً');
    }

    final bytes = base64Decode(data['audio'] as String);
    final fmt = (data['format'] as String?) ?? 'wav';
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tts_${_uuid.v4()}.$fmt';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
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
        HealthStatus.sleeping => 'الخادم نائم — افتح المساحة',
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
