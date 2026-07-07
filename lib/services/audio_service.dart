import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// خدمة الصوت: تسجيل من الميكروفون + تشغيل الملفات الناتجة.
class AudioService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  static const _uuid = Uuid();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// طلب إذن الميكروفون
  Future<bool> ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// بدء التسجيل، يعيد مسار الملف الذي سيُكتب إليه
  Future<String?> startRecording() async {
    if (!await ensureMicPermission()) return null;
    if (!await _recorder.hasPermission()) return null;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${_uuid.v4()}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000, // 16kHz يكفي لـ Whisper ويقلّل الحجم
        numChannels: 1,
      ),
      path: path,
    );
    _isRecording = true;
    return path;
  }

  /// إيقاف التسجيل، يعيد مسار الملف المسجّل
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  /// إلغاء التسجيل الحالي دون حفظ
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  /// تدفّق مستوى الصوت (لرسم الموجة أثناء التسجيل)
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  /// تشغيل ملف صوت
  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  /// انتظار انتهاء التشغيل الحالي
  Future<void> get onComplete => _player.onPlayerComplete.first;

  Future<void> stopPlayback() => _player.stop();

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
