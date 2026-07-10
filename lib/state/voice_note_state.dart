import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/voice_note.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import 'app_state.dart';

enum VoiceNoteStage { idle, recording, transcribing, translating, cloning, done }

/// حالة قسم رسائل واتساب الصوتية.
/// يدعم: اختيار ملف أو التسجيل المباشر، ثم تفريغ → ترجمة → استنساخ صوتي.
/// 3 عمليات مجانية، ثم اشتراك.
class VoiceNoteState extends ChangeNotifier {
  VoiceNoteState({
    required this.api,
    required this.audio,
    required this.appState,
  });

  final ApiService api;
  final AudioService audio;
  final AppState appState;

  final List<VoiceNoteTranslation> results = [];
  VoiceNoteStage stage = VoiceNoteStage.idle;
  String? error;
  String? currentUserId;
  bool _recording = false;

  bool get isBusy =>
      stage != VoiceNoteStage.idle && stage != VoiceNoteStage.done;
  bool get isRecording => _recording;

  String get stageLabel => switch (stage) {
        VoiceNoteStage.idle => '',
        VoiceNoteStage.recording => 'جارٍ التسجيل…',
        VoiceNoteStage.transcribing => 'جارٍ التفريغ…',
        VoiceNoteStage.translating => 'جارٍ الترجمة…',
        VoiceNoteStage.cloning => 'جارٍ الاستنساخ بصوتك…',
        VoiceNoteStage.done => '',
      };

  /// هل يمكن إجراء عملية جديدة (تجربة مجانية أو اشتراك)
  bool _checkQuota() {
    if (!appState.subscribed && appState.voiceNotesRemaining <= 0) {
      error = 'انتهت الرسائل المجانية الثلاث — اشترك للمتابعة';
      notifyListeners();
      return false;
    }
    return true;
  }

  /// بدء التسجيل المباشر داخل التطبيق
  Future<void> startRecording() async {
    if (!_checkQuota()) return;
    final path = await audio.startRecording();
    if (path == null) {
      error = 'تعذّر بدء التسجيل — تأكد من إذن الميكروفون';
      notifyListeners();
      return;
    }
    _recording = true;
    stage = VoiceNoteStage.recording;
    error = null;
    notifyListeners();
  }

  /// إيقاف التسجيل ومعالجته (تفريغ → ترجمة → استنساخ)
  Future<void> stopRecordingAndProcess({
    required String targetLang,
    required String sourceLang,
  }) async {
    if (!_recording) return;
    _recording = false;
    final path = await audio.stopRecording();
    if (path == null) {
      error = 'لم يُسجّل صوت';
      stage = VoiceNoteStage.idle;
      notifyListeners();
      return;
    }
    final file = File(path);
    if (await file.length() < 2000) {
      error = 'التسجيل قصير جداً — تحدّث بوضوح';
      stage = VoiceNoteStage.idle;
      notifyListeners();
      return;
    }
    await _process(
      audioPath: path,
      fileName: 'تسجيل مباشر',
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }

  /// المعالجة الكاملة: تفريغ → ترجمة → استنساخ صوتي
  Future<void> _process({
    required String audioPath,
    required String fileName,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      // 1) تفريغ (Groq)
      stage = VoiceNoteStage.transcribing;
      notifyListeners();
      final transcribed = await api.transcribe(path: audioPath, lang: sourceLang);
      if (transcribed.trim().isEmpty) {
        error = 'لم يُسمع كلام واضح';
        stage = VoiceNoteStage.idle;
        notifyListeners();
        return;
      }

      // 2) ترجمة
      stage = VoiceNoteStage.translating;
      notifyListeners();
      final translated = await api.translate(
        text: transcribed,
        from: sourceLang,
        to: targetLang,
      );

      // 3) استنساخ صوتي — الترجمة منطوقة بنبرة صوت المقطع الأصلي
      stage = VoiceNoteStage.cloning;
      notifyListeners();
      String? clonedPath;
      try {
        clonedPath = await api.synthesize(
          text: translated,
          lang: targetLang,
          refAudioPath: audioPath, // الصوت الأصلي كمرجع للنبرة
        );
      } catch (e) {
        // إن فشل الاستنساخ، نُبقي الترجمة النصية على الأقل
        debugPrint('فشل الاستنساخ: $e');
      }

      // 4) العلامة المائية
      final now = DateTime.now();
      final stamp = PrivacyWatermark.generate(
        userId: currentUserId ?? 'anon',
        timestamp: now,
      );

      results.insert(
        0,
        VoiceNoteTranslation(
          id: now.microsecondsSinceEpoch.toString(),
          originalFileName: fileName,
          transcribedText: transcribed,
          translatedText: translated,
          sourceLang: sourceLang,
          targetLang: targetLang,
          duration: 0,
          processedAt: now,
          privacyStamp: stamp,
          clonedAudioPath: clonedPath,
        ),
      );
      stage = VoiceNoteStage.done;
      await appState.consumeVoiceNote();

      // شغّل الصوت المُستنسخ تلقائياً
      if (clonedPath != null) {
        await audio.play(clonedPath);
      }
      notifyListeners();
    } catch (e) {
      error = 'فشلت المعالجة: $e';
      stage = VoiceNoteStage.idle;
      notifyListeners();
    }
  }

  /// إعادة تشغيل صوت مُستنسخ
  Future<void> replay(VoiceNoteTranslation r) async {
    if (r.clonedAudioPath != null) {
      await audio.play(r.clonedAudioPath!);
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
