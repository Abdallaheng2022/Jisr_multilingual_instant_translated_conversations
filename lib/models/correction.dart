import 'dart:math' as math;

/// عيّنة تصحيح: النص الذي أخرجه Whisper مقابل ما صحّحه المستخدم.
/// تُجمّع لتدريب نموذج التفريغ لاحقاً على الأخطاء المتكررة.
class Correction {
  final String id;
  final String userId;
  final String? audioPath; // مسار/رابط الصوت الأصلي (مطلوب للتدريب)
  final String originalText; // ما أخرجه Whisper (قد يحوي خطأ)
  final String correctedText; // ما صحّحه المستخدم
  final String language;
  final double audioDuration; // ثوانٍ
  final DateTime createdAt;

  // تُحسب تلقائياً
  final double editRatio; // نسبة التغيير (0-1)
  final double qualityScore; // 0-100
  final CorrectionStatus status;

  const Correction({
    required this.id,
    required this.userId,
    required this.originalText,
    required this.correctedText,
    required this.language,
    required this.audioDuration,
    required this.createdAt,
    required this.editRatio,
    required this.qualityScore,
    required this.status,
    this.audioPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'audioPath': audioPath,
        'originalText': originalText,
        'correctedText': correctedText,
        'language': language,
        'audioDuration': audioDuration,
        'createdAt': createdAt.toIso8601String(),
        'editRatio': editRatio,
        'qualityScore': qualityScore,
        'status': status.name,
      };

  factory Correction.fromJson(Map<String, dynamic> j) => Correction(
        id: j['id'] as String,
        userId: j['userId'] as String,
        audioPath: j['audioPath'] as String?,
        originalText: j['originalText'] as String,
        correctedText: j['correctedText'] as String,
        language: j['language'] as String,
        audioDuration: (j['audioDuration'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        editRatio: (j['editRatio'] as num).toDouble(),
        qualityScore: (j['qualityScore'] as num).toDouble(),
        status: CorrectionStatus.values.byName(j['status'] as String),
      );
}

enum CorrectionStatus {
  pending, // بانتظار التقييم
  approved, // مقبولة للتدريب
  rejected, // مرفوضة (لا تصلح)
  used, // استُخدمت في التدريب
}

/// محرّك المعايير التلقائية — يقرّر جودة العيّنة وصلاحيتها للتدريب.
///
/// هذه المعايير مبنية على أفضل ممارسات جمع بيانات ASR:
/// عيّنة سيئة تُفسد النموذج، لذا نرفض تلقائياً ما لا يستحق.
class CorrectionCriteria {
  CorrectionCriteria._();

  // حدود المدة (Whisper يُدرّب على مقاطع ≤ 30 ث)
  static const double minDuration = 1.0;
  static const double maxDuration = 30.0;

  // حدود نسبة التغيير
  static const double minEditRatio = 0.05; // أقل = تصحيح تافه
  static const double maxEditRatio = 0.40; // أكثر = إعادة كتابة مشبوهة
  static const double rejectEditRatio = 0.60; // رفض قاطع

  static const int minWords = 3;
  static const double minLanguagePurity = 0.80;
  static const double approveThreshold = 70.0; // quality_score للقبول التلقائي

  /// يقيّم عيّنة ويعيدها مع quality_score و status محسوبين.
  static Correction evaluate({
    required String id,
    required String userId,
    required String originalText,
    required String correctedText,
    required String language,
    required double audioDuration,
    String? audioPath,
    double audioClarity = 0.7, // نسبة الإشارة/الضجيج (0-1)، تُقدّر من الصوت
  }) {
    final orig = originalText.trim();
    final corr = correctedText.trim();
    final editRatio = _editRatio(orig, corr);
    final wordCount = corr.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final purity = _languagePurity(corr, language);

    final score = _qualityScore(
      audioClarity: audioClarity,
      wordCount: wordCount,
      editRatio: editRatio,
      purity: purity,
    );

    final status = _decide(
      audioDuration: audioDuration,
      editRatio: editRatio,
      wordCount: wordCount,
      purity: purity,
      score: score,
      orig: orig,
      corr: corr,
    );

    return Correction(
      id: id,
      userId: userId,
      audioPath: audioPath,
      originalText: orig,
      correctedText: corr,
      language: language,
      audioDuration: audioDuration,
      createdAt: DateTime.now(),
      editRatio: editRatio,
      qualityScore: score,
      status: status,
    );
  }

  /// القرار التلقائي: قبول/رفض/انتظار
  static CorrectionStatus _decide({
    required double audioDuration,
    required double editRatio,
    required int wordCount,
    required double purity,
    required double score,
    required String orig,
    required String corr,
  }) {
    // رفض قاطع
    if (corr.isEmpty) return CorrectionStatus.rejected;
    if (orig == corr) return CorrectionStatus.rejected; // لا تصحيح فعلي
    if (audioDuration < minDuration || audioDuration > maxDuration) {
      return CorrectionStatus.rejected;
    }
    if (wordCount < minWords) return CorrectionStatus.rejected;
    if (editRatio > rejectEditRatio) return CorrectionStatus.rejected;
    if (purity < minLanguagePurity) return CorrectionStatus.rejected;

    // قبول تلقائي: جودة عالية + تغيير في النطاق المثالي
    if (score >= approveThreshold &&
        editRatio >= minEditRatio &&
        editRatio <= maxEditRatio) {
      return CorrectionStatus.approved;
    }

    // ما بينهما → مراجعة يدوية
    return CorrectionStatus.pending;
  }

  /// quality_score (0-100) — يرتّب العيّنات حسب فائدتها للتدريب
  static double _qualityScore({
    required double audioClarity,
    required int wordCount,
    required double editRatio,
    required double purity,
  }) {
    // وضوح الصوت (30)
    final clarityScore = audioClarity.clamp(0.0, 1.0) * 30;

    // طول مناسب (20): 3-15 كلمة مثالي
    double lengthScore;
    if (wordCount >= 3 && wordCount <= 15) {
      lengthScore = 20;
    } else if (wordCount < 3) {
      lengthScore = wordCount / 3 * 20;
    } else {
      lengthScore = math.max(0, 20 - (wordCount - 15) * 0.5);
    }

    // edit_distance مثالي (30): 10-25% هو الأفضل
    double editScore;
    if (editRatio >= 0.10 && editRatio <= 0.25) {
      editScore = 30;
    } else if (editRatio < 0.10) {
      editScore = editRatio / 0.10 * 30;
    } else {
      editScore = math.max(0, 30 - (editRatio - 0.25) * 60);
    }

    // نقاء اللغة (20)
    final purityScore = purity.clamp(0.0, 1.0) * 20;

    return (clarityScore + lengthScore + editScore + purityScore)
        .clamp(0.0, 100.0);
  }

  /// نسبة التغيير بين نصّين (Levenshtein على الكلمات، مطبّعة)
  static double _editRatio(String a, String b) {
    final wa = _normalize(a).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wb = _normalize(b).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (wa.isEmpty && wb.isEmpty) return 0;
    if (wa.isEmpty || wb.isEmpty) return 1;
    final dist = _levenshtein(wa, wb);
    return dist / math.max(wa.length, wb.length);
  }

  /// تطبيع النص: إزالة علامات الترقيم والتشكيل قبل المقارنة
  /// (فرق الفاصلة أو التشكيل ليس خطأ تفريغ حقيقياً)
  static String _normalize(String s) {
    return s
        // تشكيل عربي
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        // علامات ترقيم شائعة
        .replaceAll(RegExp(r'[.,،;؛:!؟?"\x27]'), '')
        .trim();
  }

  /// Levenshtein على مستوى الكلمات
  static int _levenshtein(List<String> a, List<String> b) {
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }

  /// نقاء اللغة: نسبة الأحرف المنتمية للغة المتوقّعة
  static double _languagePurity(String text, String lang) {
    final clean = text.replaceAll(RegExp(r'[\s\d\p{P}]', unicode: true), '');
    if (clean.isEmpty) return 0;
    int matching = 0;
    for (final ch in clean.runes) {
      if (_belongsToLanguage(ch, lang)) matching++;
    }
    return matching / clean.length;
  }

  static bool _belongsToLanguage(int codeUnit, String lang) {
    switch (lang) {
      case 'ar': // عربي
        return (codeUnit >= 0x0600 && codeUnit <= 0x06FF) ||
            (codeUnit >= 0x0750 && codeUnit <= 0x077F);
      case 'hi': // هندي (ديفاناغاري)
        return codeUnit >= 0x0900 && codeUnit <= 0x097F;
      default: // لاتيني (en, tr, fr, de, es)
        return (codeUnit >= 0x0041 && codeUnit <= 0x024F);
    }
  }
}
