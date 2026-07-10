import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/voice_note.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/voice_note_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'paywall_screen.dart';
import 'language_picker_sheet.dart';

/// قسم ترجمة رسائل واتساب الصوتية — بخصوصية وعلامة مائية.
class VoiceNotesScreen extends StatelessWidget {
  const VoiceNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vn = context.watch<VoiceNoteState>();
    vn.currentUserId = context.read<AuthState>().user?.uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _header(app),
            const SizedBox(height: 12),
            _privacyBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: vn.results.isEmpty
                  ? _empty(context, app, vn)
                  : _resultsList(context, vn),
            ),
            if (vn.error != null) _errorBar(context, vn),
            const SizedBox(height: 12),
            _actionButton(context, app, vn),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(AppState app) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(child: Text('رسائل واتساب', style: AppText.h1)),
        if (!app.subscribed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: app.voiceNotesRemaining > 0
                  ? AppColors.tealSoft(0.12)
                  : AppColors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              app.voiceNotesRemaining > 0
                  ? '${app.voiceNotesRemaining} مجانية متبقية'
                  : 'انتهت المجانية',
              style: TextStyle(
                color: app.voiceNotesRemaining > 0
                    ? AppColors.teal
                    : AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// شعار الخصوصية — يطمئن المستخدم أن رسائله خاصة
  Widget _privacyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealSoft(0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teal.withOpacity(0.2), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: AppColors.teal, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'رسائلك تُعالج بخصوصية تامة. كل ترجمة تحمل علامة مائية تثبت أنها لم تُخزّن أو يُطّلع عليها.',
            style: TextStyle(
                color: AppColors.textDim, fontSize: 11.5, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _empty(BuildContext context, AppState app, VoiceNoteState vn) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: AppColors.tealSoft(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: const Icon(Icons.mic_none_rounded,
                color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('ترجم رسائل واتساب الصوتية',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'شارك رسالة صوتية من واتساب إلى جسر، أو اخترها من الملفات، لتحصل على ترجمتها فوراً',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsList(BuildContext context, VoiceNoteState vn) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: vn.results.length,
      itemBuilder: (_, i) => _resultCard(vn, vn.results[i]),
    );
  }

  Widget _resultCard(VoiceNoteState vn, VoiceNoteTranslation r) {
    final src = langByCode(r.sourceLang);
    final tgt = langByCode(r.targetLang);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // اسم الملف
                Row(children: [
                  const Icon(Icons.audio_file_outlined,
                      color: AppColors.muted, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.originalFileName,
                        style:
                            TextStyle(color: AppColors.faint, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 12),
                // النص الأصلي
                Row(children: [
                  Text(src.flag, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(src.native, style: AppText.label),
                ]),
                const SizedBox(height: 5),
                Directionality(
                  textDirection: src.rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(r.transcribedText, style: AppText.bodyDim),
                ),
                const SizedBox(height: 12),
                const Divider(
                    color: AppColors.border, height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                // الترجمة + زر الاستماع بالصوت المُستنسخ
                Row(children: [
                  Text(tgt.flag, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(tgt.native, style: AppText.label),
                  const Spacer(),
                  if (r.clonedAudioPath != null)
                    GestureDetector(
                      onTap: () => vn.replay(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.amberGradient,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: AppColors.bg, size: 14),
                              SizedBox(width: 5),
                              Text('استمع بصوته',
                                  style: TextStyle(
                                      color: AppColors.bg,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 5),
                Directionality(
                  textDirection: tgt.rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(r.translatedText, style: AppText.body),
                ),
              ],
            ),
          ),
          // العلامة المائية (ختم الخصوصية)
          _watermark(r),
        ],
      ),
    );
  }

  /// العلامة المائية المعروضة أسفل كل ترجمة
  Widget _watermark(VoiceNoteTranslation r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealSoft(0.06),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.lg)),
        border: Border(
            top: BorderSide(color: AppColors.teal.withOpacity(0.15), width: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_user_outlined,
            color: AppColors.teal, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            PrivacyWatermark.displayLabel(r.processedAt),
            style: const TextStyle(
                color: AppColors.teal,
                fontSize: 10,
                fontWeight: FontWeight.w500),
          ),
        ),
        Text(r.privacyStamp,
            style: TextStyle(
                color: AppColors.faint,
                fontSize: 9,
                fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _errorBar(BuildContext context, VoiceNoteState vn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(vn.error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _actionButton(BuildContext context, AppState app, VoiceNoteState vn) {
    final locked = !app.subscribed && app.voiceNotesRemaining <= 0;
    final busy = vn.isBusy;

    // أثناء التسجيل: زر إيقاف
    if (vn.isRecording) {
      return GestureDetector(
        onTap: () => vn.stopRecordingAndProcess(
          sourceLang: app.sourceLang.code,
          targetLang: app.targetLang.code,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stop_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('إيقاف وترجمة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    if (busy) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.teal)),
            const SizedBox(width: 10),
            Text(vn.stageLabel,
                style:
                    const TextStyle(color: AppColors.textDim, fontSize: 14)),
          ]),
        ),
      );
    }

    if (locked) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaywallScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: AppColors.tealGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, color: AppColors.bg, size: 18),
              SizedBox(width: 8),
              Text('اشترك للمتابعة',
                  style: TextStyle(
                      color: AppColors.bg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    // الوضع العادي: زرّان (تسجيل مباشر + اختيار ملف)
    return Row(children: [
      // تسجيل مباشر
      Expanded(
        flex: 3,
        child: GestureDetector(
          onTap: () => vn.startRecording(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_rounded, color: AppColors.bg, size: 18),
                SizedBox(width: 8),
                Text('سجّل صوتك',
                    style: TextStyle(
                        color: AppColors.bg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // اختيار ملف واتساب
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: () => vn.pickAndProcess(
            sourceLang: app.sourceLang.code,
            targetLang: app.targetLang.code,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upload_file_rounded,
                    color: AppColors.teal, size: 17),
                SizedBox(width: 6),
                Text('ملف',
                    style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
