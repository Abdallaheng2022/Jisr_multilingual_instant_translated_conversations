import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/voice_note.dart';
import '../models/fingerprint.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/voice_note_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fingerprint_sheet.dart';
import 'paywall_screen.dart';
import 'language_picker_sheet.dart';

/// Voice translation section: 3 input methods (WhatsApp share / record / type),
/// voice fingerprint reference, target-language selection, and cloning.
class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  InputMethod _method = InputMethod.record;
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

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
            _fingerprintRow(context, vn),
            const SizedBox(height: 12),
            _methodTabs(),
            const SizedBox(height: 12),
            _languageRow(context, app),
            const SizedBox(height: 12),
            Expanded(
              child: vn.results.isEmpty
                  ? _empty()
                  : _resultsList(context, vn),
            ),
            if (vn.error != null) _errorBar(context, vn),
            const SizedBox(height: 10),
            _actionArea(context, app, vn),
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
        const Flexible(child: Text('الترجمة الصوتية', style: AppText.h1)),
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
                  ? '${app.voiceNotesRemaining} مجانية'
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

  /// Fingerprint status + record button
  Widget _fingerprintRow(BuildContext context, VoiceNoteState vn) {
    final has = vn.hasFingerprint;
    return GestureDetector(
      onTap: () => _captureFingerprint(context, vn),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: has ? AppColors.tealSoft(0.08) : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: has ? AppColors.teal.withOpacity(0.3) : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(children: [
          Icon(
            has ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
            color: has ? AppColors.teal : AppColors.muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              has
                  ? 'بصمة صوتك جاهزة — سيُنطق الكلام بصوتك'
                  : 'سجّل بصمة صوتك (5 ثوانٍ) للاستنساخ',
              style: TextStyle(
                color: has ? AppColors.teal : AppColors.textDim,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            has ? 'تغيير' : 'تسجيل',
            style: const TextStyle(color: AppColors.amber, fontSize: 12),
          ),
        ]),
      ),
    );
  }

  /// Three input-method tabs
  Widget _methodTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: InputMethod.values.map((m) {
          final selected = _method == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _method = m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    m.label,
                    style: TextStyle(
                      color: selected ? AppColors.bg : AppColors.muted,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Source → target language selector
  Widget _languageRow(BuildContext context, AppState app) {
    return Row(children: [
      Expanded(child: _langChip(context, app.sourceLang, true)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.arrow_back_rounded,
            color: AppColors.muted, size: 18),
      ),
      Expanded(child: _langChip(context, app.targetLang, false)),
    ]);
  }

  Widget _langChip(BuildContext context, Language lang, bool isSource) {
    return GestureDetector(
      onTap: () => _pickLang(context, isSource),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(lang.flag, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(lang.native,
                style: AppText.body, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted, size: 16),
        ]),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: AppColors.tealSoft(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: const Icon(Icons.graphic_eq_rounded,
                color: AppColors.teal, size: 28),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              _method == InputMethod.text
                  ? 'اكتب نصاً، اختر اللغة، وستسمعه مترجماً بصوتك'
                  : 'سجّل أو شارك صوتاً، وستسمعه مترجماً بالصوت',
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
                              Text('استمع',
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
          _watermark(r),
        ],
      ),
    );
  }

  Widget _watermark(VoiceNoteTranslation r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealSoft(0.06),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.lg)),
        border: Border(
            top: BorderSide(
                color: AppColors.teal.withOpacity(0.15), width: 0.5)),
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
                color: AppColors.faint, fontSize: 9, fontFamily: 'monospace')),
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

  /// Action area changes with the selected method
  Widget _actionArea(BuildContext context, AppState app, VoiceNoteState vn) {
    final locked = !app.subscribed && app.voiceNotesRemaining <= 0;
    if (locked) {
      return _lockedButton(context);
    }
    if (vn.isBusy) {
      return _busyButton(vn);
    }

    switch (_method) {
      case InputMethod.text:
        return _textInputArea(context, app, vn);
      case InputMethod.whatsappShare:
        return _shareButton(context, app, vn);
      case InputMethod.record:
        return _recordButton(context, app, vn);
    }
  }

  Widget _textInputArea(
      BuildContext context, AppState app, VoiceNoteState vn) {
    return Column(children: [
      TextField(
        controller: _textCtrl,
        maxLines: 2,
        minLines: 1,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: 'اكتب ما تريد ترجمته…',
          hintStyle: TextStyle(color: AppColors.faint, fontSize: 14),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      const SizedBox(height: 10),
      _primaryButton(
        icon: Icons.translate_rounded,
        label: 'ترجم وانطق بصوتي',
        onTap: () {
          vn.processText(
            text: _textCtrl.text,
            sourceLang: app.sourceLang.code,
            targetLang: app.targetLang.code,
          );
        },
      ),
    ]);
  }

  Widget _shareButton(BuildContext context, AppState app, VoiceNoteState vn) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.muted, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'من واتساب: شارك الرسالة الصوتية واختر «جسر». (قريباً — استخدم التسجيل الآن)',
              style: TextStyle(color: AppColors.textDim, fontSize: 11),
            ),
          ),
        ]),
      ),
      _primaryButton(
        icon: Icons.mic_rounded,
        label: 'سجّل بدلاً من ذلك',
        onTap: () => setState(() => _method = InputMethod.record),
      ),
    ]);
  }

  Widget _recordButton(BuildContext context, AppState app, VoiceNoteState vn) {
    if (vn.isRecording) {
      return _primaryButton(
        icon: Icons.stop_rounded,
        label: 'إيقاف وترجمة',
        color: AppColors.danger,
        onTap: () => vn.stopRecordingAndProcess(
          sourceLang: app.sourceLang.code,
          targetLang: app.targetLang.code,
        ),
      );
    }
    return _primaryButton(
      icon: Icons.mic_rounded,
      label: 'سجّل صوتك',
      onTap: () => vn.startRecording(),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: color == null ? AppColors.tealGradient : null,
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.bg, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.bg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _busyButton(VoiceNoteState vn) {
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
              style: const TextStyle(color: AppColors.textDim, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _lockedButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
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

  Future<void> _captureFingerprint(
      BuildContext context, VoiceNoteState vn) async {
    final fp = await showModalBottomSheet<VoiceFingerprint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FingerprintSheet(audio: vn.audio),
    );
    if (fp != null && fp.isValid) {
      vn.setFingerprint(fp.path);
    }
  }

  void _pickLang(BuildContext context, bool isSource) {
    final app = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguagePickerSheet(
        selected: isSource ? app.sourceLang : app.targetLang,
        onPick: (lang) {
          if (isSource) {
            app.setSource(lang);
          } else {
            app.setTarget(lang);
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}
