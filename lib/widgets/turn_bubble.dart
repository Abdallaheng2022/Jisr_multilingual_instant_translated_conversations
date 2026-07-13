import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// فقاعة دور ترجمة: نص أصلي + ترجمة + زر إعادة تشغيل الصوت
class TurnBubble extends StatelessWidget {
  final TurnResult turn;
  final bool speaking;
  final VoidCallback onReplay;
  final VoidCallback? onEdit;

  const TurnBubble({
    super.key,
    required this.turn,
    required this.onReplay,
    this.onEdit,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // النص الأصلي + زر التصحيح
          Row(children: [
            Expanded(
              child: _row(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.teal,
                label: '${turn.src.native} · أنت',
              ),
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined,
                        color: AppColors.amber, size: 13),
                    SizedBox(width: 4),
                    Text('صحّح',
                        style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 9),
          Directionality(
            textDirection:
                turn.src.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Text(turn.original, style: AppText.body),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1, thickness: 0.5),
          const SizedBox(height: 11),
          // الترجمة
          Row(children: [
            _miniIcon(Icons.volume_up_rounded, AppColors.amber),
            const SizedBox(width: 7),
            Text('${turn.tgt.native} · بصوتك', style: AppText.label),
            const Spacer(),
            if (turn.audioPath != null)
              GestureDetector(
                onTap: onReplay,
                child: speaking
                    ? const Waveform(color: AppColors.amber)
                    : const Icon(Icons.replay_rounded,
                        color: AppColors.amber, size: 18),
              ),
          ]),
          const SizedBox(height: 7),
          Directionality(
            textDirection:
                turn.tgt.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Text(turn.translated, style: AppText.bodyDim),
          ),
        ],
      ),
    );
  }

  Widget _row(
      {required IconData icon,
      required Color iconColor,
      required String label}) {
    return Row(children: [
      _miniIcon(icon, iconColor),
      const SizedBox(width: 7),
      Text(label, style: AppText.label),
    ]);
  }

  Widget _miniIcon(IconData icon, Color color) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, color: color, size: 13),
      );
}
