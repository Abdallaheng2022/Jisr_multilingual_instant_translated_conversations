import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/ondevice/ondevice_voice.dart';
import '../services/room_service.dart';
import 'app_state.dart';

enum RoomStatus { none, creating, waiting, joined, recording, processing }

/// حالة الغرفة الصوتية بين هاتفين (بالتناوب مع استنساخ).
class RoomState extends ChangeNotifier {
  RoomState({
    required this.api,
    required this.audio,
    required this.rooms,
    required this.appState,
    required this.onDevice,
  });

  final ApiService api;
  final AudioService audio;
  final RoomService rooms;

  /// لمعرفة هل المستخدم مشترك (يحدّد: Modal أم محرّكات الجهاز)
  final AppState appState;

  /// محرّكات الجهاز (الطبقة المجانية)
  final OnDeviceVoice onDevice;

  RoomStatus status = RoomStatus.none;
  String? roomCode;
  bool isHost = false;
  String? error;

  String myId = '';
  String myName = 'مستخدم';
  String myLang = 'ar'; // لغتي (أتحدث بها)
  String otherLang = 'en'; // لغة الطرف الآخر (أسمعه بها بعد الترجمة)
  bool _otherJoined = false;
  bool get otherJoined => _otherJoined;

  final List<RoomMessage> messages = [];
  StreamSubscription? _msgSub;
  StreamSubscription? _stateSub;
  String? _refAudioPath; // صوتي المرجعي للاستنساخ

  bool get inRoom => roomCode != null;
  bool get isRecording => status == RoomStatus.recording;

  /// إنشاء غرفة جديدة (المضيف)
  Future<void> createRoom({
    required String userId,
    required String userName,
    required String myLanguage,
    required String otherLanguage,
  }) async {
    error = null;
    status = RoomStatus.creating;
    notifyListeners();
    try {
      myId = userId;
      myName = userName;
      myLang = myLanguage;
      otherLang = otherLanguage;
      isHost = true;
      final code = RoomService.generateCode();
      await rooms.createRoom(
        code: code,
        hostId: userId,
        hostName: userName,
        hostLang: myLanguage,
      );
      roomCode = code;
      status = RoomStatus.waiting;
      _listen(code);
      notifyListeners();
    } catch (e) {
      error = 'تعذّر إنشاء الغرفة: $e';
      status = RoomStatus.none;
      notifyListeners();
    }
  }

  /// الانضمام لغرفة عبر رمز (الضيف)
  Future<void> joinRoom({
    required String code,
    required String userId,
    required String userName,
    required String myLanguage,
  }) async {
    error = null;
    status = RoomStatus.creating;
    notifyListeners();
    try {
      myId = userId;
      myName = userName;
      myLang = myLanguage;
      isHost = false;
      final hostData = await rooms.joinRoom(
        code: code,
        guestId: userId,
        guestName: userName,
        guestLang: myLanguage,
      );
      if (hostData == null) {
        error = 'الغرفة غير موجودة — تأكد من الرمز';
        status = RoomStatus.none;
        notifyListeners();
        return;
      }
      // لغة الطرف الآخر (المضيف) هي ما أسمعه مترجماً
      final host = hostData['host'] as Map?;
      otherLang = host?['lang'] ?? 'en';
      roomCode = code;
      _otherJoined = true;
      status = RoomStatus.joined;
      _listen(code);
      notifyListeners();
    } catch (e) {
      error = 'تعذّر الانضمام: $e';
      status = RoomStatus.none;
      notifyListeners();
    }
  }

  void _listen(String code) {
    // استمع للرسائل
    _msgSub = rooms.messages(code).listen((msgs) {
      messages
        ..clear()
        ..addAll(msgs);
      // شغّل آخر رسالة واردة من الطرف الآخر تلقائياً
      if (msgs.isNotEmpty && msgs.last.senderId != myId) {
        final last = msgs.last;
        if (last.audioUrl != null) {
          audio.playUrl(last.audioUrl!);
        }
      }
      notifyListeners();
    });
    // استمع لحالة الغرفة (انضمام الطرف الآخر)
    _stateSub = rooms.roomState(code).listen((state) {
      if (state == null) {
        // الغرفة أُغلقت
        _handleRoomClosed();
        return;
      }
      final guest = state['guest'] as Map?;
      if (guest != null && !_otherJoined) {
        _otherJoined = true;
        otherLang = guest['lang'] ?? otherLang;
        if (status == RoomStatus.waiting) status = RoomStatus.joined;
        notifyListeners();
      }
    });
  }

  void _handleRoomClosed() {
    if (!isHost) {
      error = 'أغلق المضيف الغرفة';
    }
    _cleanup();
    notifyListeners();
  }

  /// بدء التسجيل
  Future<void> startRecording() async {
    if (!_otherJoined) {
      error = 'انتظر انضمام الطرف الآخر أولاً';
      notifyListeners();
      return;
    }
    final path = await audio.startRecording();
    if (path == null) {
      error = 'تعذّر التسجيل — تأكد من إذن الميكروفون';
      notifyListeners();
      return;
    }
    status = RoomStatus.recording;
    error = null;
    notifyListeners();
  }

  /// إيقاف التسجيل، ترجمة، استنساخ، وإرسال للطرف الآخر
  Future<void> stopAndSend() async {
    if (status != RoomStatus.recording) return;
    final path = await audio.stopRecording();
    status = RoomStatus.processing;
    notifyListeners();

    if (path == null) {
      status = RoomStatus.joined;
      notifyListeners();
      return;
    }
    _refAudioPath ??= path;

    try {
      // 1) تفريغ بلغتي — المشترك: Groq | المجاني: Whisper على الجهاز
      final original = appState.subscribed
          ? await api.transcribe(path: path, lang: myLang)
          : await onDevice.transcribe(path: path, lang: myLang);
      if (original.trim().isEmpty) {
        error = 'لم يُسمع كلام واضح';
        status = RoomStatus.joined;
        notifyListeners();
        return;
      }
      // 2) ترجمة للغة الطرف الآخر
      final translated = await api.translate(
        text: original,
        from: myLang,
        to: otherLang,
      );
      // 3) توليد صوت الترجمة — المشترك: بنبرته عبر Modal | المجاني: صوت جاهز
      String? audioUrl;
      try {
        final clonedPath = appState.subscribed
            ? await api.synthesize(
                text: translated,
                lang: otherLang,
                refAudioPath: _refAudioPath,
              )
            : await onDevice.speak(text: translated, lang: otherLang);
        // ارفع الصوت المُستنسخ ليصل للطرف الآخر (عبر Storage)
        audioUrl = await rooms.uploadAudio(clonedPath, roomCode!);
      } catch (e) {
        debugPrint('فشل الاستنساخ/الرفع: $e');
      }
      // 4) أرسل الرسالة للغرفة
      await rooms.sendMessage(
        roomCode!,
        RoomMessage(
          id: '',
          senderId: myId,
          senderName: myName,
          originalText: original,
          translatedText: translated,
          sourceLang: myLang,
          targetLang: otherLang,
          audioUrl: audioUrl,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      status = RoomStatus.joined;
      notifyListeners();
    } catch (e) {
      error = 'فشلت المعالجة: $e';
      status = RoomStatus.joined;
      notifyListeners();
    }
  }

  /// مغادرة الغرفة
  Future<void> leave() async {
    if (roomCode != null) {
      await rooms.leaveRoom(roomCode!, isHost: isHost);
    }
    _cleanup();
    notifyListeners();
  }

  void _cleanup() {
    _msgSub?.cancel();
    _stateSub?.cancel();
    _msgSub = null;
    _stateSub = null;
    roomCode = null;
    _otherJoined = false;
    status = RoomStatus.none;
    messages.clear();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
