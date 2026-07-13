import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/correction.dart';
import '../models/learning.dart';

/// Database service backed by Supabase (Postgres + Storage).
/// Method signatures match the previous Firebase version so the rest of
/// the app is unchanged.
class DatabaseService {
  SupabaseClient get _db => Supabase.instance.client;

  // ── Users ──
  /// Create/update a user row (upsert on first login)
  Future<void> saveUser(AppUser user) async {
    await _db.from('users').upsert({
      'id': user.uid,
      'email': user.email,
      'display_name': user.displayName,
      'photo_url': user.photoUrl,
      'subscribed': user.subscribed,
      'plan': user.plan,
      'used_messages': user.usedMessages,
      'contribute_to_training': user.contributeToTraining,
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final row =
        await _db.from('users').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return _userFromRow(row);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    // Map camelCase keys to snake_case columns
    final mapped = <String, dynamic>{};
    fields.forEach((k, v) {
      mapped[_toSnake(k)] = v;
    });
    await _db.from('users').update(mapped).eq('id', uid);
  }

  /// Realtime stream of a user row
  Stream<AppUser?> userStream(String uid) => _db
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? null : _userFromRow(rows.first));

  AppUser _userFromRow(Map<String, dynamic> r) => AppUser(
        uid: r['id'] as String,
        email: r['email'] as String?,
        displayName: r['display_name'] as String?,
        photoUrl: r['photo_url'] as String?,
        subscribed: r['subscribed'] as bool? ?? false,
        plan: r['plan'] as String? ?? 'free',
        usedMessages: r['used_messages'] as int? ?? 0,
        contributeToTraining: r['contribute_to_training'] as bool? ?? false,
      );

  // ── Corrections ──
  Future<Correction> saveCorrection({
    required String userId,
    required String originalText,
    required String correctedText,
    required String language,
    required double audioDuration,
    String? audioLocalPath,
    bool contributeToTraining = false,
    double audioClarity = 0.7,
  }) async {
    // نُقيّم دائماً (للاستخدام المحلي)، لكن لا نحفظ شيئاً بلا إذن
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final evaluated = CorrectionCriteria.evaluate(
      id: id,
      userId: userId,
      originalText: originalText,
      correctedText: correctedText,
      language: language,
      audioDuration: audioDuration,
      audioPath: null,
      audioClarity: audioClarity,
    );

    // ⚠️ بلا إذن → لا يُحفظ شيء (لا نص ولا صوت)
    if (!contributeToTraining) return evaluated;

    // Upload audio (consent granted)
    String? audioUrl;
    if (audioLocalPath != null && File(audioLocalPath).existsSync()) {
      try {
        final path = 'training_audio/$language/$id.wav';
        await _db.storage.from('training').upload(path, File(audioLocalPath));
        audioUrl = _db.storage.from('training').getPublicUrl(path);
      } catch (_) {
        // storage failure shouldn't block saving the text
      }
    }

    final correction = CorrectionCriteria.evaluate(
      id: id,
      userId: userId,
      originalText: originalText,
      correctedText: correctedText,
      language: language,
      audioDuration: audioDuration,
      audioPath: audioUrl,
      audioClarity: audioClarity,
    );

    await _db.from('corrections').insert({
      'user_id': userId,
      'audio_url': audioUrl,
      'original_text': correction.originalText,
      'corrected_text': correction.correctedText,
      'language': language,
      'audio_duration': audioDuration,
      'edit_ratio': correction.editRatio,
      'quality_score': correction.qualityScore,
      'status': correction.status.name,
    });
    return correction;
  }

  Future<List<Correction>> userCorrections(String userId,
      {int limit = 50}) async {
    final rows = await _db
        .from('corrections')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => _correctionFromRow(r)).toList();
  }

  Future<int> approvedCount(String language) async {
    final rows = await _db
        .from('corrections')
        .select('id')
        .eq('language', language)
        .eq('status', 'approved');
    return (rows as List).length;
  }

  Correction _correctionFromRow(Map<String, dynamic> r) => Correction(
        id: r['id'].toString(),
        userId: r['user_id'] as String,
        audioPath: r['audio_url'] as String?,
        originalText: r['original_text'] as String,
        correctedText: r['corrected_text'] as String,
        language: r['language'] as String,
        audioDuration: (r['audio_duration'] as num).toDouble(),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
        editRatio: (r['edit_ratio'] as num?)?.toDouble() ?? 0,
        qualityScore: (r['quality_score'] as num?)?.toDouble() ?? 0,
        status: CorrectionStatus.values.byName(r['status'] as String),
      );

  // ── Learned phrases ──
  Future<void> saveLearnedPhrase(String userId, LearnedPhrase phrase) async {
    await _db.from('learned_phrases').insert({
      'user_id': userId,
      'source_text': phrase.sourceText,
      'target_text': phrase.targetText,
      'source_lang': phrase.sourceLang,
      'target_lang': phrase.targetLang,
      'review_count': phrase.reviewCount,
      'mastered': phrase.mastered,
    });
  }

  Future<List<LearnedPhrase>> learnedPhrases(String userId,
      {int limit = 100}) async {
    final rows = await _db
        .from('learned_phrases')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => _phraseFromRow(r)).toList();
  }

  Future<void> updatePhrase(
      String userId, String phraseId, Map<String, dynamic> fields) async {
    final mapped = <String, dynamic>{};
    fields.forEach((k, v) => mapped[_toSnake(k)] = v);
    await _db.from('learned_phrases').update(mapped).eq('id', phraseId);
  }

  Future<void> deletePhrase(String userId, String phraseId) async {
    await _db.from('learned_phrases').delete().eq('id', phraseId);
  }

  LearnedPhrase _phraseFromRow(Map<String, dynamic> r) => LearnedPhrase(
        id: r['id'].toString(),
        sourceText: r['source_text'] as String,
        targetText: r['target_text'] as String,
        sourceLang: r['source_lang'] as String,
        targetLang: r['target_lang'] as String,
        learnedAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
        reviewCount: r['review_count'] as int? ?? 0,
        mastered: r['mastered'] as bool? ?? false,
      );

  // ── Recordings (كل جلسات الترجمة والتسجيلات) ──
  /// يحفظ جلسة ترجمة كاملة (نص + ترجمة + صوت)
  /// ⚠️ لا يُحفظ شيء إن لم يمنح المستخدم الإذن (consent)
  Future<void> saveRecording({
    required String userId,
    required String originalText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
    required bool consent, // إذن المستخدم — إلزامي
    String? correctedText,
    bool wasCorrected = false,
    String? audioLocalPath,
    String? clonedLocalPath,
    double audioDuration = 0,
    String section = 'translate',
  }) async {
    // بلا إذن → لا حفظ إطلاقاً (لا نص، لا صوت)
    if (!consent) return;

    // ⚠️ توفير Storage:
    //    • saveRecording لا يرفع صوتاً إطلاقاً (سجلّ نصي فقط)
    //    • الصوت يُرفع مرة واحدة فقط عبر saveCorrection (عيّنات التدريب)
    //    • الصوت المُستنسخ لا يُخزّن (المستخدم سمعه)
    try {
      await _db.from('recordings').insert({
        'user_id': userId,
        'original_text': originalText,
        'corrected_text': correctedText,
        'translated_text': translatedText,
        'was_corrected': wasCorrected,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'audio_url': null, // الصوت في جدول corrections (بلا ازدواج)
        'cloned_audio_url': null,
        'audio_duration': audioDuration,
        'section': section,
        'consent': true,
      });
    } catch (e) {
      // لا نُفشل التطبيق إن تعذّر الحفظ
    }
  }

  /// جلب آخر تصحيحات المستخدم (لبناء "معرفة" توجّه النموذج فوراً)
  /// ⚠️ تُستخدم فقط إن وافق المستخدم
  Future<List<String>> recentCorrectedTexts(
    String userId, {
    required String language,
    int limit = 8,
  }) async {
    try {
      final rows = await _db
          .from('corrections')
          .select('corrected_text')
          .eq('user_id', userId)
          .eq('language', language)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => (r['corrected_text'] as String?) ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// جلب تسجيلات المستخدم (للعرض/التحليل)
  Future<List<Map<String, dynamic>>> userRecordings(String userId,
      {int limit = 100}) async {
    final rows = await _db
        .from('recordings')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ── Quota (الرصيد اليومي على الخادم — يتبع الحساب لا الجهاز) ──

  /// يخصم من الرصيد اليومي على الخادم.
  /// يعيد: {ok, remaining, subscribed} — ok=false يعني نفد الرصيد.
  Future<Map<String, dynamic>> consumeQuota({
    required String kind, // 'translate' | 'voice_note'
    required int limit,
  }) async {
    try {
      final res = await _db.rpc('consume_quota', params: {
        'p_kind': kind,
        'p_limit': limit,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      // فشل الاتصال → نسمح محلياً (لا نمنع المستخدم بسبب مشكلة شبكة)
      return {'ok': true, 'remaining': -1, 'offline': true};
    }
  }

  /// يقرأ الرصيد الحالي (بلا خصم)
  Future<Map<String, dynamic>?> getQuota() async {
    try {
      final res = await _db.rpc('get_quota');
      final m = Map<String, dynamic>.from(res as Map);
      return m['ok'] == true ? m : null;
    } catch (_) {
      return null;
    }
  }

  // ── Learning summaries ──
  Future<void> saveLearningSummary({
    required String userId,
    required String sourceLang,
    required String targetLang,
    required List<String> phrases,
  }) async {
    await _db.from('learning_summaries').insert({
      'user_id': userId,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'phrases': phrases,
    });
  }

  // Helper: camelCase → snake_case
  static String _toSnake(String s) => s.replaceAllMapped(
      RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
}
