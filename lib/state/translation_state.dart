import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import 'app_state.dart';

enum PipelineStage { idle, recording, transcribing, translating, speaking }

/// حالة شاشة الترجمة: قائمة الأدوار + سير العملية (تسجيل ← ترجمة ← نطق).
class TranslationState extends ChangeNotifier {
  TranslationState({
    required this.api,
    required this.audio,
    required this.appState,
  });

  final ApiService api;
  final AudioService audio;
  final AppState appState;

  final List<TurnResult> turns = [];
  PipelineStage stage = PipelineStage.idle;
  String? error;
  String? _refAudioPath; // صوت المستخدم المرجعي (لاستنساخه)

  bool get isBusy => stage != PipelineStage.idle;

  String get stageLabel => switch (stage) {
        PipelineStage.idle => '',
        PipelineStage.recording => 'جارٍ الاستماع…',
        PipelineStage.transcribing => 'جارٍ التفريغ…',
        PipelineStage.translating => 'جارٍ الترجمة…',
        PipelineStage.speaking => 'جارٍ النطق بصوتك…',
      };

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
    }
  }

  /// تفريغ صوتي — يستدعي مسار STT في السيرفر الوسيط.
  /// (السيرفر يمرّره لخدمة STT مثل Whisper؛ هنا نرسل الملف كـ multipart.)
  Future<String> _transcribe(String path) async {
    // نفوّض التفريغ لطبقة API. نضيفها هنا للحفاظ على المسؤولية الواحدة.
    return api.transcribe(path: path, lang: appState.sourceLang.code);
  }

  Future<void> replay(TurnResult turn) async {
    if (turn.audioPath != null) {
      await audio.play(turn.audioPath!);
    }
  }

  void clear() {
    turns.clear();
    notifyListeners();
  }
}
