import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// عميل يتصل بـ Hugging Face Space مباشرة (Gradio API) — بدون سيرفر وسيط.
///
/// الـ Space يوفّر ثلاث دوال:
///   /gradio_api/call/tts        → توليد صوت مستنسخ
///   /gradio_api/call/translate  → ترجمة (MADLAD-400)
///   /gradio_api/call/stt        → تفريغ صوتي (Whisper)
///
/// كل نداء على خطوتين: POST يعيد event_id، ثم GET يبثّ النتيجة (SSE).
class ApiService {
  ApiService({required this.baseUrl, this.hfToken});

  /// رابط الـ Space، مثل: https://abdo96-chatterbox.hf.space
  final String baseUrl;

  /// توكن HF (فقط إن كان الـ Space خاصاً)
  final String? hfToken;

  static const _uuid = Uuid();
  final _client = http.Client();

  Uri _u(String path) => Uri.parse('$baseUrl$path');
  Map<String, String> _authHeaders() =>
      hfToken != null ? {'Authorization': 'Bearer $hfToken'} : {};

  // أسماء اللغات كما يتوقعها الـ Space (dropdown labels)
  static const _langLabels = {
    'ar': 'العربية (ar)',
    'tr': 'Türkçe (tr)',
    'en': 'English (en)',
    'hi': 'हिन्दी (hi)',
    'es': 'Español (es)',
    'de': 'Deutsch (de)',
    'fr': 'Français (fr)',
  };
  String _label(String code) => _langLabels[code] ?? code;

  // ============================================================
  //  مُنادٍ عام لـ Gradio (خطوتان: call ثم SSE)
  // ============================================================
  Future<dynamic> _callGradio(
    String endpoint,
    List<dynamic> data, {
    Duration timeout = const Duration(seconds: 180),
  }) async {
    // 1) إرسال الطلب
    final callRes = await _client
        .post(
          _u('/gradio_api/call/$endpoint'),
          headers: {'Content-Type': 'application/json', ..._authHeaders()},
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));
    if (callRes.statusCode != 200) {
      throw ApiException('$endpoint: HTTP ${callRes.statusCode}');
    }
    final eventId = (jsonDecode(callRes.body) as Map)['event_id'];
    if (eventId == null) throw ApiException('$endpoint: لا يوجد event_id');

    // 2) قراءة النتيجة عبر SSE
    final resultReq = http.Request('GET', _u('/gradio_api/call/$endpoint/$eventId'));
    resultReq.headers.addAll(_authHeaders());
    final streamed = await _client.send(resultReq).timeout(timeout);
    final body = await streamed.stream.bytesToString();

    String event = '';
    dynamic result;
    for (final line in body.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final d = line.substring(5).trim();
        if (event == 'error') {
          // أظهر تفاصيل الخطأ الفعلية من الخادم بدل رسالة عامة
          throw ApiException('$endpoint: $d');
        }
        if (event == 'complete') {
          final parsed = jsonDecode(d);
          result = parsed is List ? (parsed.isNotEmpty ? parsed[0] : null) : parsed;
        }
      }
    }
    return result;
  }

  // ============================================================
  //  رفع ملف لـ Gradio (مطلوب قبل التفريغ)
  // ============================================================
  Future<Map<String, dynamic>> _uploadFile(String path) async {
    final req = http.MultipartRequest('POST', _u('/gradio_api/upload'));
    req.headers.addAll(_authHeaders());
    req.files.add(await http.MultipartFile.fromPath('files', path));
    final streamed = await _client.send(req).timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw ApiException('فشل رفع الصوت: HTTP ${res.statusCode}');
    }
    final paths = jsonDecode(res.body) as List;
    final serverPath = paths.first as String;
    return {
      'path': serverPath,
      'orig_name': path.split('/').last,
      'url': null,
      'meta': {'_type': 'gradio.FileData'},
    };
  }

  // ============================================================
  //  فحص الاتصال
  // ============================================================
  Future<HealthStatus> checkHealth() async {
    try {
      final res = await _client
          .get(_u('/'), headers: _authHeaders())
          .timeout(const Duration(seconds: 15));
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
    final result = await _callGradio(
      'translate',
      [text, _label(from), _label(to)],
      timeout: const Duration(seconds: 120),
    );
    return (result as String?)?.trim() ?? text;
  }

  // ============================================================
  //  تفريغ صوتي (رفع الملف ثم نداء stt)
  // ============================================================
  Future<String> transcribe({
    required String path,
    required String lang,
  }) async {
    final fileRef = await _uploadFile(path);
    final result = await _callGradio(
      'stt',
      [fileRef, _label(lang)],
      timeout: const Duration(seconds: 120),
    );
    return (result as String?)?.trim() ?? '';
  }

  // ============================================================
  //  توليد صوت مستنسخ (يعيد مسار ملف محلي)
  // ============================================================
  Future<String> synthesize({
    required String text,
    required String lang,
    String? refAudioPath,
  }) async {
    // صوت مرجعي اختياري: نرفعه أولاً إن وُجد
    dynamic voiceRef;
    if (refAudioPath != null && File(refAudioPath).existsSync()) {
      voiceRef = await _uploadFile(refAudioPath);
    }

    // tts(text, language, exaggeration, cfg_weight, voice_ref)
    final result = await _callGradio(
      'tts',
      [text, _label(lang), 0.5, 0.5, voiceRef],
      timeout: const Duration(seconds: 180),
    );

    // النتيجة كائن ملف {url, path, ...} — ننزّله محلياً
    if (result == null) throw ApiException('لم يُرجع الخادم صوتاً');
    final url = result is Map
        ? (result['url'] as String?)
        : (result as String?);
    if (url == null) throw ApiException('رابط الصوت مفقود');

    final audioRes = await _client
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 60));
    if (audioRes.statusCode != 200) {
      throw ApiException('فشل تنزيل الصوت: HTTP ${audioRes.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/tts_${_uuid.v4()}.wav';
    await File(outPath).writeAsBytes(audioRes.bodyBytes, flush: true);
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
