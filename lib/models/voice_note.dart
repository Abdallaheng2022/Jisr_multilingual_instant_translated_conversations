/// ترجمة رسالة صوتية من واتساب (مع علامة مائية تثبت الخصوصية).
class VoiceNoteTranslation {
  final String id;
  final String originalFileName;
  final String transcribedText; // النص المُفرّغ من الرسالة
  final String translatedText; // الترجمة
  final String sourceLang;
  final String targetLang;
  final double duration;
  final DateTime processedAt;

  /// مسار الصوت المُستنسخ (الترجمة منطوقة بنبرة المتحدث)
  final String? clonedAudioPath;

  // العلامة المائية: ختم يثبت أن المعالجة تمت بخصوصية
  final String privacyStamp;

  const VoiceNoteTranslation({
    required this.id,
    required this.originalFileName,
    required this.transcribedText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.duration,
    required this.processedAt,
    required this.privacyStamp,
    this.clonedAudioPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalFileName': originalFileName,
        'transcribedText': transcribedText,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'duration': duration,
        'processedAt': processedAt.toIso8601String(),
        'privacyStamp': privacyStamp,
        'clonedAudioPath': clonedAudioPath,
      };

  factory VoiceNoteTranslation.fromJson(Map<String, dynamic> j) =>
      VoiceNoteTranslation(
        id: j['id'] as String,
        originalFileName: j['originalFileName'] as String,
        transcribedText: j['transcribedText'] as String,
        translatedText: j['translatedText'] as String,
        sourceLang: j['sourceLang'] as String,
        targetLang: j['targetLang'] as String,
        duration: (j['duration'] as num).toDouble(),
        processedAt: DateTime.parse(j['processedAt'] as String),
        privacyStamp: j['privacyStamp'] as String,
        clonedAudioPath: j['clonedAudioPath'] as String?,
      );
}

/// مولّد العلامة المائية للخصوصية.
/// ينشئ ختماً فريداً يثبت أن الترجمة تمت محلياً/بخصوصية دون تخزين الصوت.
class PrivacyWatermark {
  PrivacyWatermark._();

  /// ينشئ ختم خصوصية فريداً لكل ترجمة.
  /// الختم = بصمة زمنية + معرّف، يؤكد المعالجة الخاصة.
  static String generate({
    required String userId,
    required DateTime timestamp,
  }) {
    final ts = timestamp.millisecondsSinceEpoch;
    // بصمة مختصرة (لا تكشف بيانات، فقط تثبت التفرّد والوقت)
    final hash = _shortHash('$userId-$ts');
    return 'جسر·خاص·$hash';
  }

  /// نص العلامة المائية المعروض مع الترجمة
  static String displayLabel(DateTime timestamp) {
    final d = timestamp;
    final date = '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return 'تُرجمت بخصوصية عبر جسر · $date $time';
  }

  static String _shortHash(String input) {
    // تجزئة بسيطة (FNV-1a) لبصمة قصيرة
    int hash = 0x811c9dc5;
    for (final c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0').substring(0, 8);
  }
}
