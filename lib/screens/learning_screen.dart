import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/learning.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/learning_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// قسم تعلّم اللغة: يعرض العبارات المتعلّمة من محادثات الترجمة كبطاقات مراجعة.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthState>();
    final learning = context.read<LearningState>();
    if (auth.user != null) learning.load(auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _header(learning),
            const SizedBox(height: 16),
            if (learning.loading)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.teal)),
              )
            else if (learning.phrases.isEmpty)
              Expanded(child: _empty())
            else
              Expanded(child: _list(context, learning)),
          ],
        ),
      ),
    );
  }

  Widget _header(LearningState learning) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('تعلّم اللغة', style: AppText.h1),
        if (learning.total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tealSoft(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${learning.masteredCount}/${learning.total} أُتقنت',
              style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _empty() {
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
            child: const Icon(Icons.school_rounded,
                color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('لا عبارات بعد',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'ترجم محادثات في قسم الترجمة، وستُحفظ العبارات المفيدة هنا تلقائياً للمراجعة',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, LearningState learning) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: learning.phrases.length,
      itemBuilder: (_, i) {
        final phrase = learning.phrases[i];
        return _card(context, learning, phrase);
      },
    );
  }

  Widget _card(
      BuildContext context, LearningState learning, LearnedPhrase phrase) {
    final src = langByCode(phrase.sourceLang);
    final tgt = langByCode(phrase.targetLang);
    final level = PhraseExtractor.levelOf(phrase.sourceText);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: phrase.mastered
            ? AppColors.tealSoft(0.06)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: phrase.mastered ? AppColors.teal.withOpacity(0.3) : AppColors.border,
          width: phrase.mastered ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // اللغة المصدر + المستوى
          Row(children: [
            Text(src.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(src.native, style: AppText.label),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _levelColor(level).withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(level.label,
                  style: TextStyle(color: _levelColor(level), fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 8),
          Directionality(
            textDirection: src.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Text(phrase.sourceText, style: AppText.body),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          // الترجمة
          Row(children: [
            Text(tgt.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(tgt.native, style: AppText.label),
          ]),
          const SizedBox(height: 6),
          Directionality(
            textDirection: tgt.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Text(phrase.targetText, style: AppText.bodyDim),
          ),
          const SizedBox(height: 12),
          // أزرار
          Row(children: [
            GestureDetector(
              onTap: () => learning.toggleMastered(phrase),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: phrase.mastered
                      ? AppColors.teal
                      : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    phrase.mastered
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 15,
                    color: phrase.mastered ? AppColors.bg : AppColors.muted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    phrase.mastered ? 'أتقنتها' : 'أتقنتها؟',
                    style: TextStyle(
                        fontSize: 12,
                        color: phrase.mastered ? AppColors.bg : AppColors.muted),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            if (phrase.reviewCount > 0)
              Text('${phrase.reviewCount} مراجعة',
                  style: TextStyle(color: AppColors.faint, fontSize: 11)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDelete(context, learning, phrase),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.faint, size: 18),
            ),
          ]),
        ],
      ),
    );
  }

  Color _levelColor(PhraseLevel level) => switch (level) {
        PhraseLevel.easy => AppColors.ok,
        PhraseLevel.medium => AppColors.amber,
        PhraseLevel.hard => AppColors.danger,
      };

  void _confirmDelete(
      BuildContext context, LearningState learning, LearnedPhrase phrase) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('حذف العبارة؟', style: AppText.h2),
        content: Text('ستُحذف من قائمة التعلّم نهائياً.',
            style: AppText.bodyDim),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              learning.remove(phrase);
              Navigator.pop(context);
            },
            child: const Text('حذف',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
