import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'paywall_screen.dart';

/// الغرفة الصوتية اللايف — مكالمة بالتناوب مع ترجمة فورية بصوت المتحدث.
class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({super.key});

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  bool _inCall = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _muted = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleCall(AppState app) {
    if (!_inCall) {
      // المشتركون: دخول حر. غير المشتركين: تجربة 3 دقائق
      if (!app.subscribed && app.voiceTrialRemaining <= 0) {
        // انتهت التجربة المجانية → صفحة الاشتراك
        _showTrialEndedDialog(app);
        return;
      }
      setState(() => _inCall = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
        // خصم من التجربة المجانية (لغير المشتركين)
        if (!app.subscribed) {
          app.consumeVoiceTrial(1);
          // انتهى الوقت المجاني → إنهاء المكالمة وعرض القفل
          if (app.voiceTrialRemaining <= 0) {
            _endCall();
            _showTrialEndedDialog(app);
          }
        }
      });
    } else {
      _endCall();
    }
  }

  void _endCall() {
    _timer?.cancel();
    setState(() {
      _inCall = false;
      _elapsed = Duration.zero;
    });
  }

  void _showTrialEndedDialog(AppState app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.amber, size: 20),
          const SizedBox(width: 8),
          const Text('انتهت التجربة', style: AppText.h2),
        ]),
        content: Text(
          'استمتعت بـ 3 دقائق مجانية في الغرفة الصوتية! '
          'اشترك للاستمرار في المكالمات غير المحدودة بصوتك المستنسخ.',
          style: AppText.bodyDim,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PaywallScreen()));
            },
            child: const Text('اشترك الآن',
                style: TextStyle(
                    color: AppColors.teal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String get _time {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          const SizedBox(height: 8),
          _header(),
          const SizedBox(height: 6),
          Text(_inCall ? _time : 'غير متصل',
              style: const TextStyle(color: AppColors.faint, fontSize: 12)),
          const SizedBox(height: 24),
          _participants(app),
          const SizedBox(height: 26),
          if (_inCall) _liveTranscript() else _idleHint(app),
          const Spacer(),
          _callControls(app),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('غرفة صوتية', style: AppText.h2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: (_inCall ? AppColors.danger : AppColors.faint)
                .withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: _inCall ? AppColors.danger : AppColors.faint,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(_inCall ? 'مباشر' : 'متوقف',
                style: TextStyle(
                    color: _inCall ? AppColors.danger : AppColors.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    );
  }

  Widget _participants(AppState app) {
    return Row(children: [
      Expanded(
        child: _participantCard(
          name: 'أنت',
          emoji: '👤',
          lang: app.sourceLang,
          gradient: AppColors.tealGradient,
          accent: AppColors.teal,
          speaking: _inCall && !_muted,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _participantCard(
          name: 'الطرف الآخر',
          emoji: '🧑',
          lang: app.targetLang,
          gradient: AppColors.amberGradient,
          accent: AppColors.amber,
          speaking: false,
        ),
      ),
    ]);
  }

  Widget _participantCard({
    required String name,
    required String emoji,
    required Language lang,
    required Gradient gradient,
    required Color accent,
    required bool speaking,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: speaking ? accent.withOpacity(0.1) : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: speaking ? accent.withOpacity(0.4) : AppColors.border,
            width: speaking ? 1 : 0.5),
      ),
      child: Column(children: [
        if (speaking)
          Align(
            alignment: Alignment.topRight,
            child: Waveform(color: accent, height: 16),
          )
        else
          const SizedBox(height: 16),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: speaking
                ? [
                    BoxShadow(
                        color: accent.withOpacity(0.3),
                        blurRadius: 0,
                        spreadRadius: 6)
                  ]
                : null,
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(lang.flag, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(lang.native,
                style: TextStyle(color: accent, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _liveTranscript() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.graphic_eq_rounded, color: AppColors.teal, size: 16),
          const SizedBox(width: 8),
          Text('جارٍ الترجمة الفورية…',
              style: TextStyle(color: AppColors.teal, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Text('تحدّث وسيسمع الطرف الآخر كلامك مترجماً بصوتك خلال لحظات',
            style: AppText.caption, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _idleHint(AppState app) {
    final showTrial = !app.subscribed;
    final mins = app.voiceTrialRemaining ~/ 60;
    final secs = app.voiceTrialRemaining % 60;
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
            color: AppColors.tealSoft(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: const Icon(Icons.headset_mic_rounded,
            color: AppColors.teal, size: 30),
      ),
      const SizedBox(height: 16),
      const Text('ابدأ مكالمة مترجمة',
          style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Text(
          'كل طرف يتحدث بلغته، ويسمع الآخر مترجماً بنبرة صوت المتحدث نفسه',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ),
      if (showTrial) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: app.voiceTrialRemaining > 0
                ? AppColors.tealSoft(0.12)
                : AppColors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              app.voiceTrialRemaining > 0
                  ? Icons.card_giftcard_rounded
                  : Icons.lock_rounded,
              size: 15,
              color: app.voiceTrialRemaining > 0
                  ? AppColors.teal
                  : AppColors.amber,
            ),
            const SizedBox(width: 7),
            Text(
              app.voiceTrialRemaining > 0
                  ? 'تجربة مجانية: ${mins}:${secs.toString().padLeft(2, '0')} متبقية'
                  : 'انتهت التجربة — اشترك للمتابعة',
              style: TextStyle(
                fontSize: 12,
                color: app.voiceTrialRemaining > 0
                    ? AppColors.teal
                    : AppColors.amber,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ],
    ]);
  }

  Widget _callControls(AppState app) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (_inCall) ...[
        _circleBtn(
          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          bg: AppColors.surface2,
          onTap: () => setState(() => _muted = !_muted),
        ),
        const SizedBox(width: 18),
      ],
      GestureDetector(
        onTap: () => _toggleCall(app),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient:
                _inCall ? AppColors.dangerGradient : AppColors.tealGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: (_inCall ? AppColors.danger : AppColors.teal)
                      .withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Icon(
              _inCall ? Icons.call_end_rounded : Icons.call_rounded,
              color: Colors.white,
              size: 30),
        ),
      ),
      if (_inCall) ...[
        const SizedBox(width: 18),
        _circleBtn(
            icon: Icons.volume_up_rounded,
            bg: AppColors.surface2,
            onTap: () {}),
      ],
    ]);
  }

  Widget _circleBtn(
      {required IconData icon,
      required Color bg,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
    );
  }
}
