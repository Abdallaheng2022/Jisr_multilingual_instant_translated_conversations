import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// حوار تعديل النص المُفرّغ — يتيح للمستخدم تصحيح ما أخطأ فيه Whisper.
/// يعيد النص المُصحّح (أو null إن ألغى).
class EditTranscriptionSheet extends StatefulWidget {
  final String originalText;
  final bool rtl;

  const EditTranscriptionSheet({
    super.key,
    required this.originalText,
    this.rtl = true,
  });

  @override
  State<EditTranscriptionSheet> createState() => _EditTranscriptionSheetState();
}

class _EditTranscriptionSheetState extends State<EditTranscriptionSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.originalText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            const Icon(Icons.edit_rounded, color: AppColors.teal, size: 18),
            const SizedBox(width: 8),
            const Text('صحّح النص', style: AppText.h2),
            const Spacer(),
            Text('يساعد في تحسين الدقة',
                style: TextStyle(color: AppColors.faint, fontSize: 11)),
          ]),
          const SizedBox(height: 16),
          Directionality(
            textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              style: AppText.body,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide:
                      const BorderSide(color: AppColors.teal, width: 1),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                      child: Text('إلغاء',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 15))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _controller.text.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                      child: Text('حفظ التصحيح',
                          style: TextStyle(
                              color: AppColors.bg,
                              fontSize: 15,
                              fontWeight: FontWeight.w600))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
