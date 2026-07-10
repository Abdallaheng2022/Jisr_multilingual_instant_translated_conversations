/// عبارة تعلّمها المستخدم من محادثة ترجمة (نص أصلي ↔ ترجمة)
class LearnedPhrase {
  final String id;
  final String sourceText; // النص بلغة المستخدم
  final String targetText; // الترجمة
  final String sourceLang;
  final String targetLang;
  final DateTime learnedAt;
  int reviewCount; // كم مرة راجعها
  bool mastered; // أتقنها؟

  LearnedPhrase({
    required this.id,
    required this.sourceText,
    required this.targetText,
    required this.sourceLang,
    required this.targetLang,
    required this.learnedAt,
    this.reviewCount = 0,
    this.mastered = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceText': sourceText,
        'targetText': targetText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'learnedAt': learnedAt.toIso8601String(),
        'reviewCount': reviewCount,
        'mastered': mastered,
      };

  factory LearnedPhrase.fromJson(Map<String, dynamic> j) => LearnedPhrase(
        id: j['id'] as String,
        sourceText: j['sourceText'] as String,
        targetText: j['targetText'] as String,
        sourceLang: j['sourceLang'] as String,
        targetLang: j['targetLang'] as String,
        learnedAt: DateTime.parse(j['learnedAt'] as String),
        reviewCount: j['reviewCount'] as int? ?? 0,
        mastered: j['mastered'] as bool? ?? false,
      );
}

/// منطق استخراج العبارات القابلة للتعلّم من دورة ترجمة.
class PhraseExtractor {
  PhraseExtractor._();

  /// يقرّر إن كانت الدورة تستحق الحفظ كعبارة تعلّم.
  /// نحفظ العبارات القصيرة-المتوسطة (مفيدة للتعلّم)، لا الجُمل الطويلة جداً.
  static bool isWorthLearning(String sourceText, String targetText) {
    final srcWords = _wordCount(sourceText);
    final tgtWords = _wordCount(targetText);
    // بين كلمة و 12 كلمة: عبارات مفيدة للحفظ
    if (srcWords < 1 || srcWords > 12) return false;
    if (tgtWords < 1 || tgtWords > 15) return false;
    // تجنّب النصوص الفارغة أو الرموز فقط
    if (sourceText.trim().isEmpty || targetText.trim().isEmpty) return false;
    return true;
  }

  static int _wordCount(String s) =>
      s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// مستوى صعوبة تقديري (للترتيب/التصنيف)
  static PhraseLevel levelOf(String sourceText) {
    final words = _wordCount(sourceText);
    if (words <= 2) return PhraseLevel.easy;
    if (words <= 6) return PhraseLevel.medium;
    return PhraseLevel.hard;
  }
}

enum PhraseLevel { easy, medium, hard }

extension PhraseLevelX on PhraseLevel {
  String get label => switch (this) {
        PhraseLevel.easy => 'سهل',
        PhraseLevel.medium => 'متوسط',
        PhraseLevel.hard => 'متقدم',
      };
}
