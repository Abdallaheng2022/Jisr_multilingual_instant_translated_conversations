import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/turn_bubble.dart';
import '../widgets/edit_transcription_sheet.dart';
import '../widgets/consent_sheet.dart';
import 'language_picker_sheet.dart';
import 'paywall_screen.dart';

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trans = context.watch<TranslationState>();
    // زامن معرّف المستخدم لحفظ عبارات التعلّم
    final authUser = context.read<AuthState>().user;
    trans.currentUserId = authUser?.uid;
    trans.userConsent = authUser?.contributeToTraining ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _header(context, app),
            const SizedBox(height: 20),
            LanguageBar(
              source: app.sourceLang,
              target: app.targetLang,
              onSwap: app.swapLanguages,
              onTapSource: () => _pickLang(context, isSource: true),
              onTapTarget: () => _pickLang(context, isSource: false),
            ),
            const SizedBox(height: 16),
            // إشعار: يمكنك التصحيح إن وجدت خطأ
            if (trans.turns.isNotEmpty && !trans.isReviewing) _editHint(),
            // طلب الإذن (يظهر مرة، بعد أول ترجمة، إن لم يوافق بعد)
            if (trans.turns.isNotEmpty &&
                !trans.isReviewing &&
                !trans.userConsent)
              _consentBanner(context),
            Expanded(child: _feed(context, trans)),
            // بطاقة المراجعة — تظهر بعد التفريغ لتصحيح النص قبل الترجمة
            if (trans.isReviewing) _ReviewCard(trans: trans, app: app),
            if (!trans.isReviewing) _controls(context, app, trans),
            const SizedBox(height: 10),
            FreeCounter(
              remaining: app.subscribed ? 999 : app.freeRemaining,
              hoursUntilReset: app.hoursUntilReset,
              onUpgrade: () => _openPaywall(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppState app) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const JisrLogo(),
          const SizedBox(width: 11),
          const Text('جسر', style: AppText.h1),
          if (app.subscribed) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  gradient: AppColors.amberGradient,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.workspace_premium_rounded,
                    color: AppColors.bg, size: 12),
                SizedBox(width: 3),
                Text('Pro',
                    style: TextStyle(
                        color: AppColors.bg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ]),
        GestureDetector(
          onTap: () {
            app.refreshHealth();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(app.health.isReady
                    ? '✅ متصل بالخادم'
                    : 'جارٍ فحص الاتصال… ${app.health.label}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: StatusPill(
            connected: app.health.isReady,
            label: app.health.label,
          ),
        ),
      ],
    );
  }


  /// إشعار داخل التطبيق: إن وجدت خطأً، صحّحه وستُعاد الترجمة

  /// شريط طلب الإذن — يظهر إن لم يوافق المستخدم بعد
  Widget _consentBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _askConsent(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.tealSoft(0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
              color: AppColors.teal.withOpacity(0.25), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.school_outlined, color: AppColors.teal, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ساعدنا نحسّن الترجمة للعامية — تصحيحاتك تُدرّب التطبيق (اختياري)',
              style: TextStyle(color: AppColors.textDim, fontSize: 11),
            ),
          ),
          const Text('اعرف أكثر',
              style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// يفتح حوار الإذن ويحفظ الاختيار
  Future<void> _askConsent(BuildContext context) async {
    final auth = context.read<AuthState>();
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConsentSheet(
        currentValue: auth.user?.contributeToTraining ?? false,
      ),
    );
    if (agreed == null) return;
    await auth.setContributeToTraining(agreed);
  }

  Widget _editHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: AppColors.amber.withOpacity(0.2), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline_rounded,
            color: AppColors.amber, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'وجدت خطأً في النص؟ اضغط «صحّح» — سنعيد الترجمة والنطق بصوتك',
            style: TextStyle(color: AppColors.textDim, fontSize: 11),
          ),
        ),
      ]),
    );
  }

  Widget _feed(BuildContext context, TranslationState trans) {
    if (trans.turns.isEmpty) {
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
              child: const Icon(Icons.translate_rounded,
                  color: AppColors.teal, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('ابدأ بالتحدث',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('اضغط الميكروفون وتحدث بلغتك',
                style: AppText.caption, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 4),
      itemCount: trans.turns.length,
      itemBuilder: (_, i) {
        final turn = trans.turns[i];
        return TurnBubble(
          turn: turn,
          speaking: trans.stage == PipelineStage.speaking && i == 0,
          onReplay: () => trans.replay(turn),
          onEdit: () => _editTurn(context, turn),
        );
      },
    );
  }

  Widget _controls(
      BuildContext context, AppState app, TranslationState trans) {
    final recording = trans.stage == PipelineStage.recording;
    final busy = trans.isBusy && !recording;

    return Column(children: [
      if (busy)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.teal)),
            const SizedBox(width: 8),
            Text(trans.stageLabel,
                style: const TextStyle(color: AppColors.teal, fontSize: 13)),
          ]),
        ),
      if (trans.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(trans.error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
              textAlign: TextAlign.center),
        ),
      MicButton(
        recording: recording,
        onTap: () => _onMic(context, app, trans),
      ),
      const SizedBox(height: 8),
      Text(
        recording
            ? 'اضغط للإيقاف والترجمة'
            : 'اضغط للتحدث بـ${app.sourceLang.native}',
        style: AppText.caption,
      ),
    ]);
  }

  Future<void> _onMic(
      BuildContext context, AppState app, TranslationState trans) async {
    if (!app.canTranslate) {
      _openPaywall(context);
      return;
    }
    if (trans.stage == PipelineStage.recording) {
      await trans.stopAndProcess();
    } else if (trans.stage == PipelineStage.idle) {
      await trans.startListening();
    }
  }

  Future<void> _pickLang(BuildContext context,
      {required bool isSource}) async {
    final app = context.read<AppState>();
    final picked = await showModalBottomSheet<Language>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguagePickerSheet(
        selected: isSource ? app.sourceLang : app.targetLang,
      ),
    );
    if (picked == null) return;
    if (isSource) {
      app.setSource(picked);
    } else {
      app.setTarget(picked);
    }
  }

  Future<void> _editTurn(BuildContext context, TurnResult turn) async {
    final trans = context.read<TranslationState>();
    final auth = context.read<AuthState>();
    final corrected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTranscriptionSheet(
        originalText: turn.original,
        rtl: turn.src.rtl,
      ),
    );
    if (corrected == null || corrected.trim().isEmpty) return;
    if (corrected.trim() == turn.original.trim()) return;

    // احفظ التصحيح (يُطبّق المعايير التلقائية)
    final user = auth.user;
    if (user != null) {
      trans.saveCorrection(
        userId: user.uid,
        originalText: turn.original,
        correctedText: corrected,
        language: turn.srcCode,
        audioDuration: 5.0,
        contributeToTraining: user.contributeToTraining,
      );
    }

    // أعِد الترجمة والاستنساخ بالنص المصحّح
    await trans.retranslateTurn(turn, corrected.trim());
  }

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }
}

/// بطاقة مراجعة النص المُفرّغ قبل الترجمة.
/// مهمة مع اللهجات العامية حيث قد يخطئ التفريغ.
class _ReviewCard extends StatefulWidget {
  final TranslationState trans;
  final AppState app;
  const _ReviewCard({required this.trans, required this.app});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.trans.pendingText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = widget.app.sourceLang.rtl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.amber.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.edit_note_rounded,
                color: AppColors.amber, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('راجع النص قبل الترجمة',
                  style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('صحّح أي خطأ (خاصة مع العامية) لتخرج الترجمة صحيحة',
              style: TextStyle(color: AppColors.faint, fontSize: 11)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: TextField(
              controller: _ctrl,
              maxLines: 3,
              minLines: 1,
              autofocus: false,
              style: AppText.body,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            // إلغاء
            GestureDetector(
              onTap: () => widget.trans.cancelReview(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            // تأكيد وترجمة
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    widget.trans.confirmAndTranslate(_ctrl.text.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.translate_rounded,
                          color: AppColors.bg, size: 16),
                      SizedBox(width: 6),
                      Text('ترجم',
                          style: TextStyle(
                              color: AppColors.bg,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
