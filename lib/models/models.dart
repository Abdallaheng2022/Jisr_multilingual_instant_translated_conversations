import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// لغة مدعومة
class Language {
  final String code;
  final String name;
  final String native;
  final String flag;
  final bool rtl;

  const Language({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
    required this.rtl,
  });

  factory Language.fromJson(Map<String, dynamic> j) => Language(
        code: j['code'] as String,
        name: j['name'] as String,
        native: j['native'] as String? ?? j['name'] as String,
        flag: j['flag'] as String? ?? '🌐',
        rtl: j['rtl'] as bool? ?? false,
      );
}

/// اللغات السبع الأساسية (نفس قائمة التطبيق الأصلي، مختصرة لما يدعمه Chatterbox جيداً)
const kLanguages = <Language>[
  Language(code: 'ar', name: 'Arabic', native: 'العربية', flag: '🇸🇦', rtl: true),
  Language(code: 'en', name: 'English', native: 'English', flag: '🇬🇧', rtl: false),
  Language(code: 'tr', name: 'Turkish', native: 'Türkçe', flag: '🇹🇷', rtl: false),
  Language(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷', rtl: false),
  Language(code: 'de', name: 'German', native: 'Deutsch', flag: '🇩🇪', rtl: false),
  Language(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸', rtl: false),
  Language(code: 'hi', name: 'Hindi', native: 'हिन्दी', flag: '🇮🇳', rtl: false),
];

Language langByCode(String code) =>
    kLanguages.firstWhere((l) => l.code == code, orElse: () => kLanguages.first);

/// نتيجة دورة ترجمة واحدة (نص أصلي + ترجمة + صوت مستنسخ)
class TurnResult {
  final String id;
  final String side; // "A" أو "B"
  final String original;
  final String translated;
  final String? audioPath; // مسار ملف الصوت المحفوظ محلياً
  final String srcCode;
  final String tgtCode;
  final DateTime at;

  const TurnResult({
    required this.id,
    required this.side,
    required this.original,
    required this.translated,
    required this.srcCode,
    required this.tgtCode,
    required this.at,
    this.audioPath,
  });

  Language get src => langByCode(srcCode);
  Language get tgt => langByCode(tgtCode);

  TurnResult copyWith({String? translated, String? audioPath}) => TurnResult(
        id: id,
        side: side,
        original: original,
        translated: translated ?? this.translated,
        srcCode: srcCode,
        tgtCode: tgtCode,
        at: at,
        audioPath: audioPath ?? this.audioPath,
      );
}

/// خطط الاشتراك
enum PlanType { free, monthly, yearly }

class SubscriptionPlan {
  final PlanType type;
  final String id; // معرّف المنتج في Google Play
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool highlighted;
  final Gradient accent;

  const SubscriptionPlan({
    required this.type,
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.accent,
    this.highlighted = false,
  });
}

const kPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    type: PlanType.monthly,
    id: 'jisr_monthly_10',
    title: 'شهري',
    price: '\$10',
    period: 'كل شهر',
    accent: AppColors.tealGradient,
    features: [
      'ترجمة صوتية غير محدودة',
      'استنساخ صوتك بكل اللغات',
      'الغرفة الصوتية اللايف',
      'جودة صوت عالية',
    ],
  ),
  SubscriptionPlan(
    type: PlanType.yearly,
    id: 'jisr_yearly_100',
    title: 'سنوي',
    price: '\$100',
    period: 'كل سنة',
    highlighted: true,
    accent: AppColors.amberGradient,
    features: [
      'كل مزايا الاشتراك الشهري',
      'وفّر \$20 سنوياً',
      'أولوية في السرعة',
      'دعم مباشر',
    ],
  ),
];
