import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/learning.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import 'app_state.dart';

enum PipelineStage { idle, recording, transcribing, reviewing, translating, speaking }

/// حالة شاشة الترجمة: قائمة الأدوار + سير العملية (تسجيل ← ترجمة ← نطق).
class TranslationState extends ChangeNotifier {
  TranslationState({
    required this.api,
    required this.audio,
    required this.appState,
    required this.db,
  });

  final ApiService api;
  final AudioService audio;
  final AppState appState;
  final DatabaseService db;

  /// معرّف المستخدم الحالي (يُضبط من الشاشة) — لحفظ عبارات التعلّم
  String? currentUserId;

  final List<TurnResult> turns = [];
  PipelineStage stage = PipelineStage.idle;
  String? error;

  Timer? _wakeTimer; // مؤقّت رسالة "الخادم يستيقظ"

  /// مراجعة النص المُفرّغ قبل الترجمة (مهم مع اللهجات العامية)
  bool reviewBeforeTranslate = true;
  String? pendingText; // النص المُفرّغ بانتظار المراجعة
  String? pendingAudioPath; // الصوت المرافق
  String? _refAudioPath; // صوت المستخدم المرجعي (لاستنساخه)
  bool _serverWaking = false; // يصبح true إذا طال الطلب (برود الخادم)

  bool get isBusy =>
      stage != PipelineStage.idle && stage != PipelineStage.reviewing;
  bool get isReviewing => stage == PipelineStage.reviewing;
  bool get serverWaking => _serverWaking;

  String get stageLabel {
    // إن طال الانتظار، أظهر رسالة إيقاظ الخادم بدل المرحلة العادية
    if (_serverWaking && stage != PipelineStage.idle) {
      return 'الخادم يستيقظ… قد يستغرق أول طلب دقيقة، والطلبات التالية فورية';
    }
    return switch (stage) {
      PipelineStage.idle => '',
      PipelineStage.recording => 'جارٍ الاستماع…',
      PipelineStage.transcribing => 'جارٍ التفريغ…',
      PipelineStage.reviewing => 'راجع النص قبل الترجمة',
      PipelineStage.translating => 'جارٍ الترجمة…',
      PipelineStage.speaking => 'جارٍ النطق بصوتك…',
    };
  }

  /// بدء التسجيل (يُستدعى عند الضغط على الميكروفون)
  Future<bool> startListening() async {
    error = null;
    if (!appState.canTranslate) {
      error = 'انتهت رسائلك المجانية — اشترك للمتابعة';
      notifyListeners();
      return false;
    }
    final path = await audio.startRecording();
    if (path == null) {
      error = 'لم يُسمح باستخدام الميكروفون';
      notifyListeners();
      return false;
    }
    stage = PipelineStage.recording;
    notifyListeners();
    return true;
  }

  /// إيقاف التسجيل وبدء خط المعالجة الكامل
  Future<void> stopAndProcess() async {
    if (stage != PipelineStage.recording) return;
    final recPath = await audio.stopRecording();
    if (recPath == null) {
      stage = PipelineStage.idle;
      notifyListeners();
      return;
    }

    // نحفظ أول تسجيل كصوت مرجعي للاستنساخ في الأدوار التالية
    _refAudioPath ??= recPath;

    // مؤقّت: إن طال الطلب >8 ثوانٍ، أظهر رسالة "الخادم يستيقظ"
    _startWakeTimer();

    try {
      // تحقق أن التسجيل ليس فارغاً (حجم معقول)
      final recFile = File(recPath);
      final recSize = await recFile.length();
      if (recSize < 2000) {
        error = 'التسجيل قصير جداً أو فارغ — تأكد من إذن الميكروفون وتحدّث بوضوح';
        stage = PipelineStage.idle;
        notifyListeners();
        return;
      }

      // 1) تفريغ صوتي (STT) عبر السيرفر
      stage = PipelineStage.transcribing;
      notifyListeners();
      final original = await _transcribe(recPath);
      if (original.trim().isEmpty) {
        error = 'لم يُسمع كلام واضح — حاول التحدث بصوت أعلى وأقرب للميكروفون';
        stage = PipelineStage.idle;
        notifyListeners();
        return;
      }

      // 2) توقّف للمراجعة — يرى المستخدم النص ويصححه قبل الترجمة
      //    (مهم مع اللهجات العامية حيث قد يخطئ التفريغ)
      if (reviewBeforeTranslate) {
        pendingText = original;
        pendingAudioPath = recPath;
        stage = PipelineStage.reviewing;
        notifyListeners();
        return; // ننتظر confirmAndTranslate من الواجهة
      }

      await _translateAndSpeak(original, recPath);
    } catch (e) {
      error = 'فشلت المعالجة: $e';
      stage = PipelineStage.idle;
      notifyListeners();
    }
  }

  /// يُستدعى من الواجهة بعد مراجعة/تصحيح النص المُفرّغ
  Future<void> confirmAndTranslate(String finalText) async {
    final audioPath = pendingAudioPath;
    final originalTranscript = pendingText;
    pendingText = null;
    pendingAudioPath = null;

    if (finalText.trim().isEmpty || audioPath == null) {
      stage = PipelineStage.idle;
      notifyListeners();
      return;
    }

    // إن صحّح المستخدم النص، احفظه كبيانات تدريب
    if (originalTranscript != null &&
        originalTranscript.trim() != finalText.trim() &&
        currentUserId != null) {
      saveCorrection(
        userId: currentUserId!,
        originalText: originalTranscript,
        correctedText: finalText,
        language: appState.sourceLang.code,
        audioDuration: 0,
        audioPath: audioPath,
      );
    }

    try {
      await _translateAndSpeak(finalText, audioPath);
    } catch (e) {
      error = 'فشلت المعالجة: $e';
      stage = PipelineStage.idle;
      notifyListeners();
    }
  }

  /// يلغي المراجعة (يتجاهل التسجيل)
  void cancelReview() {
    pendingText = null;
    pendingAudioPath = null;
    stage = PipelineStage.idle;
    notifyListeners();
  }

  /// الترجمة + النطق (بعد تأكيد النص)
  Future<void> _translateAndSpeak(String original, String recPath) async {
    _startWakeTimer(); // قد يطول الاستنساخ — أظهر رسالة الانتظار إن لزم
    try {
      // 2) ترجمة
      stage = PipelineStage.translating;
      notifyListeners();
      final translated = await api.translate(
        text: original,
        from: appState.sourceLang.code,
        to: appState.targetLang.code,
      );

      // أضف الدور للقائمة (بدون صوت بعد)
      final turn = TurnResult(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        side: 'A',
        original: original,
        translated: translated,
        srcCode: appState.sourceLang.code,
        tgtCode: appState.targetLang.code,
        at: DateTime.now(),
      );
      turns.insert(0, turn);
      notifyListeners();

      // احفظ العبارة للتعلّم إن كانت تستحق (بلا تعطيل التدفّق)
      _maybeSaveLearnedPhrase(original, translated);

      // 3) توليد الصوت بصوت المستخدم المستنسخ
      stage = PipelineStage.speaking;
      notifyListeners();
      final audioPath = await api.synthesize(
        text: translated,
        lang: appState.targetLang.code,
        refAudioPath: _refAudioPath,
      );

      // حدّث الدور بمسار الصوت وشغّله
      final idx = turns.indexWhere((t) => t.id == turn.id);
      if (idx != -1) {
        turns[idx] = turns[idx].copyWith(audioPath: audioPath);
      }
      await appState.consumeMessage();
      stage = PipelineStage.idle;
      notifyListeners();

      await audio.play(audioPath);
    } catch (e) {
      error = e.toString();
      stage = PipelineStage.idle;
      notifyListeners();
    } finally {
      _stopWakeTimer();
    }
  }

  /// تفريغ صوتي — يستدعي مسار STT في السيرفر الوسيط.
  /// (السيرفر يمرّره لخدمة STT مثل Whisper؛ هنا نرسل الملف كـ multipart.)
  void _startWakeTimer() {
    _wakeTimer?.cancel();
    _serverWaking = false;
    _wakeTimer = Timer(const Duration(seconds: 8), () {
      _serverWaking = true;
      notifyListeners();
    });
  }

  void _stopWakeTimer() {
    _wakeTimer?.cancel();
    _wakeTimer = null;
    _serverWaking = false;
  }

  Future<String> _transcribe(String path) async {
    // نفوّض التفريغ لطبقة API. نضيفها هنا للحفاظ على المسؤولية الواحدة.
    return api.transcribe(path: path, lang: appState.sourceLang.code);
  }

  Future<void> replay(TurnResult turn) async {
    if (turn.audioPath != null) {
      await audio.play(turn.audioPath!);
    }
  }

  /// يحفظ العبارة للتعلّم إن استحقّت ووُجد مستخدم مسجّل.
  Future<void> _maybeSaveLearnedPhrase(String source, String target) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!PhraseExtractor.isWorthLearning(source, target)) return;
    try {
      final phrase = LearnedPhrase(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sourceText: source,
        targetText: target,
        sourceLang: appState.sourceLang.code,
        targetLang: appState.targetLang.code,
        learnedAt: DateTime.now(),
      );
      await db.saveLearnedPhrase(uid, phrase);
    } catch (e) {
      debugPrint('فشل حفظ عبارة التعلّم: $e');
    }
  }

  /// حفظ تصحيح المستخدم لنص مُفرّغ.
  /// يُطبّق المعايير التلقائية ويخزّن العيّنة (مع الصوت إن وافق المستخدم).
  Future<void> saveCorrection({
    required String userId,
    required String originalText,
    required String correctedText,
    required String language,
    required double audioDuration,
    String? audioPath,
    bool contributeToTraining = false,
  }) async {
    if (correctedText.trim() == originalText.trim()) return; // لا تغيير
    try {
      await db.saveCorrection(
        userId: userId,
        originalText: originalText,
        correctedText: correctedText,
        language: language,
        audioDuration: audioDuration,
        audioLocalPath: audioPath,
        contributeToTraining: contributeToTraining,
      );
    } catch (e) {
      // فشل الحفظ لا يجب أن يعطّل التطبيق
      debugPrint('فشل حفظ التصحيح: $e');
    }
  }

  void clear() {
    turns.clear();
    notifyListeners();
  }
}
