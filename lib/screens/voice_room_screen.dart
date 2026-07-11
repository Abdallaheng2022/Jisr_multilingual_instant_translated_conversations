import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart' show backendReady;
import '../models/models.dart';
import '../services/room_service.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/room_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'paywall_screen.dart';

/// الغرفة الصوتية: مكالمة حقيقية بين هاتفين عبر رمز غرفة.
class VoiceRoomScreen extends StatelessWidget {
  const VoiceRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomState>();

    // الخادم مطلوب للغرف
    if (!backendReady) {
      return _needBackend();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: room.inRoom ? _RoomView() : _LobbyView(),
      ),
    );
  }

  Widget _needBackend() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.muted, size: 40),
              const SizedBox(height: 16),
              const Text('الغرفة الصوتية تحتاج تسجيل الدخول',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('سجّل الدخول لإنشاء غرف ومكالمات',
                  style: AppText.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة اللوبي: إنشاء غرفة أو الانضمام برمز
class _LobbyView extends StatefulWidget {
  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final room = context.watch<RoomState>();
    final auth = context.read<AuthState>();

    // قفل: غير المشتركين يحتاجون تجربة/اشتراك
    final locked = !app.subscribed && app.voiceTrialRemaining <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text('غرفة صوتية', style: AppText.h1),
        const SizedBox(height: 6),
        Text('تحدّث مع أي شخص، كلٌّ بلغته، بصوت مُستنسخ',
            style: AppText.bodyDim),
        const SizedBox(height: 24),

        if (room.error != null) _errorBar(room.error!),

        // إنشاء غرفة
        _bigButton(
          icon: Icons.add_circle_outline_rounded,
          label: 'أنشئ غرفة جديدة',
          gradient: AppColors.tealGradient,
          onTap: locked
              ? () => _goPaywall(context)
              : () => _createRoom(context, app, auth),
        ),
        const SizedBox(height: 16),

        Row(children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('أو', style: AppText.caption),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ]),
        const SizedBox(height: 16),

        // الانضمام برمز
        const Text('انضم بغرفة موجودة', style: AppText.label),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'رمز الغرفة',
                hintStyle: TextStyle(
                    color: AppColors.faint,
                    fontSize: 15,
                    letterSpacing: 1),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _joinRoom(context, auth),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.login_rounded,
                  color: AppColors.bg, size: 22),
            ),
          ),
        ]),

        if (!app.subscribed) ...[
          const SizedBox(height: 20),
          Center(
            child: Text(
              app.voiceTrialRemaining > 0
                  ? 'تجربة مجانية متبقية: ${app.voiceTrialRemaining ~/ 60}:${(app.voiceTrialRemaining % 60).toString().padLeft(2, '0')}'
                  : 'انتهت التجربة المجانية',
              style: TextStyle(
                  color: app.voiceTrialRemaining > 0
                      ? AppColors.teal
                      : AppColors.amber,
                  fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _createRoom(
      BuildContext context, AppState app, AuthState auth) async {
    await context.read<RoomState>().createRoom(
          userId: auth.user?.uid ?? 'host_${DateTime.now().millisecondsSinceEpoch}',
          userName: auth.user?.displayName ?? 'المضيف',
          myLanguage: app.sourceLang.code,
          otherLanguage: app.targetLang.code,
        );
  }

  Future<void> _joinRoom(BuildContext context, AuthState auth) async {
    final app = context.read<AppState>();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      context.read<RoomState>().error = 'أدخل رمز غرفة صحيح';
      return;
    }
    await context.read<RoomState>().joinRoom(
          code: code,
          userId: auth.user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
          userName: auth.user?.displayName ?? 'ضيف',
          myLanguage: app.sourceLang.code,
        );
  }

  void _goPaywall(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.bg, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.bg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _errorBar(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 12))),
        ]),
      );
}

/// شاشة الغرفة النشطة: الرمز + المحادثة + زر التحدث
class _RoomView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // رأس: الرمز + مغادرة
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رمز الغرفة', style: AppText.caption),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: room.roomCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('نُسخ الرمز'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: Row(children: [
                    Text(room.roomCode ?? '',
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3)),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded,
                        color: AppColors.muted, size: 16),
                  ]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.read<RoomState>().leave(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text('مغادرة',
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // حالة الطرف الآخر
        _statusBanner(room),
        const SizedBox(height: 12),

        // المحادثة
        Expanded(child: _conversation(context, room)),

        // زر التحدث
        _talkButton(context, room),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _statusBanner(RoomState room) {
    final waiting = !room.otherJoined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: waiting
            ? AppColors.amber.withOpacity(0.1)
            : AppColors.tealSoft(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(waiting ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
            size: 14, color: waiting ? AppColors.amber : AppColors.teal),
        const SizedBox(width: 8),
        Text(
          waiting
              ? 'بانتظار انضمام الطرف الآخر… شارك الرمز'
              : 'الطرف الآخر متصل — يمكنك التحدث',
          style: TextStyle(
              color: waiting ? AppColors.amber : AppColors.teal,
              fontSize: 12),
        ),
      ]),
    );
  }

  Widget _conversation(BuildContext context, RoomState room) {
    if (room.messages.isEmpty) {
      return Center(
        child: Text(
          room.otherJoined
              ? 'اضغط زر التحدث لبدء المحادثة'
              : 'شارك الرمز مع من تريد التحدث معه',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      reverse: false,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: room.messages.length,
      itemBuilder: (_, i) {
        final msg = room.messages[i];
        final isMine = msg.senderId == room.myId;
        return _bubble(msg, isMine);
      },
    );
  }

  Widget _bubble(RoomMessage msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.tealSoft(0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isMine ? 'أنت' : msg.senderName,
                style: TextStyle(
                    color: isMine ? AppColors.teal : AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(msg.originalText, style: AppText.body),
            const SizedBox(height: 4),
            Text(msg.translatedText, style: AppText.bodyDim),
          ],
        ),
      ),
    );
  }

  Widget _talkButton(BuildContext context, RoomState room) {
    final processing = room.status == RoomStatus.processing;
    final recording = room.isRecording;
    final canTalk = room.otherJoined && !processing;

    if (processing) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: const Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.teal)),
            SizedBox(width: 10),
            Text('جارٍ الترجمة والاستنساخ…',
                style: TextStyle(color: AppColors.textDim, fontSize: 14)),
          ]),
        ),
      );
    }

    return GestureDetector(
      onTap: !canTalk
          ? null
          : () {
              if (recording) {
                context.read<RoomState>().stopAndSend();
              } else {
                context.read<RoomState>().startRecording();
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: recording ? AppColors.danger : null,
          gradient: recording
              ? null
              : (canTalk ? AppColors.tealGradient : null),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: canTalk || recording ? AppColors.bg : AppColors.muted,
                size: 20),
            const SizedBox(width: 8),
            Text(
              recording ? 'إيقاف وإرسال' : 'اضغط للتحدث',
              style: TextStyle(
                  color: canTalk || recording ? AppColors.bg : AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ),
    );
  }
}
