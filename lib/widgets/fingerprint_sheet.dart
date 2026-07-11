import 'dart:async';
import 'package:flutter/material.dart';

import '../models/fingerprint.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

/// حوار تسجيل بصمة الصوت (5 ثوانٍ) مع تعهّد الملكية.
/// يعيد VoiceFingerprint عند النجاح، أو null إن ألغى.
class FingerprintSheet extends StatefulWidget {
  final AudioService audio;
  const FingerprintSheet({super.key, required this.audio});

  @override
  State<FingerprintSheet> createState() => _FingerprintSheetState();
}

class _FingerprintSheetState extends State<FingerprintSheet> {
  bool _recording = false;
  bool _recorded = false;
  int _seconds = 0;
  Timer? _timer;
  String? _path;
  bool _ownershipConfirmed = false;
  String? _qualityMsg;
  bool _qualityOk = false;

  AudioService get _audio => widget.audio;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final path = await _audio.startRecording();
    if (path == null) {
      setState(() => _qualityMsg = 'تعذّر التسجيل — تأكد من إذن الميكروفون');
      return;
    }
    _path = path;
    setState(() {
      _recording = true;
      _recorded = false;
      _seconds = 0;
      _qualityMsg = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      // إيقاف تلقائي عند 5 ثوانٍ
      if (_seconds >= 5) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audio.stopRecording();
    final finalPath = path ?? _path;
    setState(() {
      _recording = false;
      _recorded = true;
    });
    if (finalPath != null) {
      _path = finalPath;
      final result = FingerprintQuality.check(finalPath, _seconds.toDouble());
      setState(() {
        _qualityOk = result.ok;
        _qualityMsg = result.message;
      });
    }
  }

  void _confirm() {
    if (_path == null || !_qualityOk || !_ownershipConfirmed) return;
    Navigator.pop(
      context,
      VoiceFingerprint(
        path: _path!,
        duration: _seconds.toDouble(),
        recordedAt: DateTime.now(),
        ownershipConfirmed: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          const Icon(Icons.fingerprint_rounded,
              color: AppColors.teal, size: 20),
          const SizedBox(width: 8),
          const Text('بصمة صوتك', style: AppText.h2),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'سجّل 5 ثوانٍ من صوتك ليُستنسخ بها كلامك المترجم',
            style: AppText.bodyDim,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 24),

        // دائرة التسجيل
        GestureDetector(
          onTap: _recording
              ? _stopRecording
              : (_recorded && _qualityOk ? null : _startRecording),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _recording
                  ? null
                  : (_recorded && _qualityOk
                      ? AppColors.tealGradient
                      : AppColors.tealGradient),
              color: _recording ? AppColors.danger : null,
            ),
            child: Center(
              child: _recording
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.stop_rounded,
                          color: Colors.white, size: 32),
                      Text('$_seconds ث',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ])
                  : Icon(
                      _recorded && _qualityOk
                          ? Icons.check_rounded
                          : Icons.mic_rounded,
                      color: AppColors.bg,
                      size: 40),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // رسالة الجودة
        if (_qualityMsg != null)
          Text(
            _qualityMsg!,
            style: TextStyle(
                color: _qualityOk ? AppColors.teal : AppColors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        if (_recorded && !_qualityOk)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: _startRecording,
              child: const Text('أعد التسجيل',
                  style: TextStyle(
                      color: AppColors.teal,
                      fontSize: 13,
                      decoration: TextDecoration.underline)),
            ),
          ),
        const SizedBox(height: 20),

        // تعهّد الملكية
        if (_recorded && _qualityOk)
          GestureDetector(
            onTap: () =>
                setState(() => _ownershipConfirmed = !_ownershipConfirmed),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _ownershipConfirmed
                    ? AppColors.tealSoft(0.1)
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _ownershipConfirmed
                      ? AppColors.teal.withOpacity(0.4)
                      : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Row(children: [
                Icon(
                  _ownershipConfirmed
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color:
                      _ownershipConfirmed ? AppColors.teal : AppColors.muted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أتعهّد أن هذا الصوت لي، وأتحمّل مسؤولية استخدامه',
                    style: TextStyle(
                        color: AppColors.text, fontSize: 13, height: 1.4),
                  ),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 20),

        // زر التأكيد
        GestureDetector(
          onTap: (_qualityOk && _ownershipConfirmed) ? _confirm : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: (_qualityOk && _ownershipConfirmed)
                  ? AppColors.tealGradient
                  : null,
              color: (_qualityOk && _ownershipConfirmed)
                  ? null
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                'تأكيد البصمة',
                style: TextStyle(
                  color: (_qualityOk && _ownershipConfirmed)
                      ? AppColors.bg
                      : AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
