import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/turn_bubble.dart';
import 'language_picker_sheet.dart';
import 'paywall_screen.dart';

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trans = context.watch<TranslationState>();

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
            Expanded(child: _feed(context, trans)),
            _controls(context, app, trans),
            const SizedBox(height: 10),
            FreeCounter(
              remaining: app.subscribed ? 999 : app.freeRemaining,
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

  void _pickLang(BuildContext context, {required bool isSource}) {
    final app = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguagePickerSheet(
        selected: isSource ? app.sourceLang : app.targetLang,
        onPick: (l) => isSource ? app.setSource(l) : app.setTarget(l),
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }
}
