import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class LanguagePickerSheet extends StatelessWidget {
  final Language selected;
  final ValueChanged<Language> onPick;

  const LanguagePickerSheet(
      {super.key, required this.selected, required this.onPick});

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
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        const Align(
          alignment: Alignment.centerRight,
          child: Text('اختر اللغة', style: AppText.h2),
        ),
        const SizedBox(height: 16),
        ...kLanguages.map((l) => _tile(context, l)),
      ]),
    );
  }

  Widget _tile(BuildContext context, Language l) {
    final active = l.code == selected.code;
    return GestureDetector(
      onTap: () {
        onPick(l);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.tealSoft(0.12) : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: active ? AppColors.teal : AppColors.border,
              width: active ? 1 : 0.5),
        ),
        child: Row(children: [
          Text(l.flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.native,
                    style: TextStyle(
                        color: active ? AppColors.teal : AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                Text(l.name, style: AppText.caption),
              ]),
          const Spacer(),
          if (active)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.teal, size: 22),
        ]),
      ),
    );
  }
}
