import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// حوار طلب إذن المساهمة ببيانات التدريب.
/// لا تُستخدم أي بيانات (لا للتدريب ولا للتحسين) دون موافقة صريحة.
class ConsentSheet extends StatefulWidget {
  final bool currentValue;
  const ConsentSheet({super.key, this.currentValue = false});

  @override
  State<ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<ConsentSheet> {
  late bool _agreed = widget.currentValue;

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
          const Icon(Icons.school_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('ساعدنا في تحسين الترجمة', style: AppText.h2),
          ),
        ]),
        const SizedBox(height: 14),

        // الشرح
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'حين تصحّح خطأً في التفريغ، يمكن لتصحيحك أن يحسّن دقة التطبيق — '
            'خاصة مع اللهجات العامية التي تخطئ فيها النماذج عادةً.',
            style: AppText.bodyDim,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 16),

        // ماذا نستخدم
        _row(Icons.check_circle_outline_rounded, AppColors.teal,
            'نصوصك المصححة (الخطأ والصواب)'),
        _row(Icons.check_circle_outline_rounded, AppColors.teal,
            'تسجيلاتك الصوتية المرافقة للتصحيح'),
        const SizedBox(height: 12),

        // ماذا لا نفعل
        _row(Icons.shield_outlined, AppColors.amber,
            'لا نشارك بياناتك مع أي طرف ثالث'),
        _row(Icons.shield_outlined, AppColors.amber,
            'يمكنك سحب الإذن في أي وقت'),
        const SizedBox(height: 18),

        // مربع الموافقة
        GestureDetector(
          onTap: () => setState(() => _agreed = !_agreed),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  _agreed ? AppColors.tealSoft(0.1) : AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _agreed
                    ? AppColors.teal.withOpacity(0.4)
                    : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(children: [
              Icon(
                _agreed
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: _agreed ? AppColors.teal : AppColors.muted,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'أوافق على استخدام تصحيحاتي وتسجيلاتي لتحسين التطبيق',
                  style: TextStyle(
                      color: AppColors.text, fontSize: 13, height: 1.4),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // الأزرار
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Text('لا، شكراً',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 14)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, _agreed),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _agreed ? AppColors.tealGradient : null,
                  color: _agreed ? null : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'حفظ',
                    style: TextStyle(
                        color: _agreed ? AppColors.bg : AppColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _row(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        ),
      ]),
    );
  }
}
