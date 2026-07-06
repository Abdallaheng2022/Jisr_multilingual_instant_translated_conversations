# جسر — تطبيق ترجمة صوتية بالاستنساخ (Flutter)

ترجمة صوتية فورية بـ 7 لغات (العربية، الإنجليزية، التركية، الفرنسية، الألمانية،
الإسبانية، الهندية) مع **استنساخ صوت المستخدم** عبر Chatterbox، وغرفة صوتية
لايف، ونظام اشتراك عبر Google Play.

## 🏗️ البنية

```
[تطبيق Flutter]
   │  يسجّل الصوت، يعرض الترجمة، يشغّل الصوت المستنسخ
   ▼
[api-server.js]  ← السيرفر الوسيط (Node، صفر تبعيات)
   │  /api/health      فحص الاتصال
   │  /api/voice/stt   تفريغ صوتي  → يمرّر لـ Whisper/Scribe
   │  /api/translate   ترجمة نص    → يمرّر لـ Google/DeepL/LibreTranslate
   │  /api/voice/tts   توليد صوت   → يمرّر لـ Chatterbox Space
   ▼
[Chatterbox HF Space]  ← النموذج (ZeroGPU)
```

## 📁 هيكل الكود

```
lib/
├── main.dart                    نقطة الدخول + Providers + RTL
├── theme/app_theme.dart         الألوان والأنماط (هوية جسر)
├── models/models.dart           Language, TurnResult, خطط الاشتراك
├── services/
│   ├── api_service.dart         الاتصال بالسيرفر (health/translate/stt/tts)
│   ├── audio_service.dart       تسجيل الميكروفون + تشغيل الصوت
│   └── billing_service.dart     اشتراكات Google Play
├── state/
│   ├── app_state.dart           العدّاد المجاني، الاشتراك، اللغات
│   └── translation_state.dart   خط المعالجة: تسجيل←تفريغ←ترجمة←نطق
├── screens/
│   ├── home_shell.dart          التنقل السفلي
│   ├── translate_screen.dart    الشاشة الرئيسية
│   ├── voice_room_screen.dart   الغرفة الصوتية اللايف
│   ├── paywall_screen.dart      شاشة الاشتراك
│   └── language_picker_sheet.dart
└── widgets/
    ├── common.dart              الشعار، الموجة، زر الميكروفون، العدّاد
    └── turn_bubble.dart         فقاعة الترجمة
```

## 🚀 التشغيل

### 1) التطبيق

```bash
flutter pub get

# شغّل مع عنوان السيرفر الوسيط
flutter run --dart-define=API_BASE_URL=https://your-server.com
```

> مبدئياً `API_BASE_URL` قيمته وهمية — لن تعمل الترجمة حتى تضبطه على سيرفرك.

### 2) السيرفر الوسيط

```bash
INFERENCE_BASE_URL=https://YOUR-USERNAME-chatterbox.hf.space \
TRANSLATE_URL=https://libretranslate.example/translate \
STT_URL=https://your-whisper-endpoint/transcribe \
node api-server.js
```

- `INFERENCE_BASE_URL` — رابط Chatterbox Space (إجباري للصوت)
- `TRANSLATE_URL` — أي مزود ترجمة يقبل `{q, source, target}` (اختياري، بدونه يعيد النص كما هو)
- `STT_URL` — خدمة تفريغ صوتي (اختياري، بدونه لا يعمل التسجيل→نص)

استضف السيرفر على Replit/Render/Railway/أي VPS، وتأكد أن التطبيق يصل إليه.

## 💳 إعداد الاشتراكات (Google Play)

1. في Google Play Console → تطبيقك → **Monetize → Products → Subscriptions**
2. أنشئ اشتراكين بنفس المعرّفات الموجودة في الكود:
   - `jisr_monthly_10` — بسعر ما يعادل \$10 شهرياً
   - `jisr_yearly_100` — بسعر ما يعادل \$100 سنوياً
3. المعرّفات معرّفة في `lib/models/models.dart` و `billing_service.dart`
4. للاختبار: أضف حسابك كـ **License tester** في Play Console

نظام **10 رسائل مجانية** يُدار محلياً في `app_state.dart` (`freeLimit = 10`)،
ويُخزَّن العدّاد بـ `shared_preferences`. بعد نفادها يفتح التطبيق شاشة الاشتراك.

## 📦 بناء APK / App Bundle للنشر

```bash
# ملف AAB للرفع على Google Play
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-server.com

# أو APK للتجربة المباشرة
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-server.com
```

الناتج في `build/app/outputs/`.

## ⚠️ ملاحظات مهمة

- **زمن الاستجابة:** أول طلب بعد خمول الـ Space يستغرق ~دقيقة (إيقاظ + تحميل
  النموذج)، ثم يصبح بالثواني. لتقليله للحد الأدنى استخدم Chatterbox Turbo على
  ZeroGPU (زمن مقطع أول ~0.5 ثانية).
- **الاستنساخ:** أول تسجيل للمستخدم يُحفظ كصوت مرجعي ويُعاد استخدامه لاستنساخ
  نبرته في كل الترجمات (منطقياً في `translation_state.dart`).
- **الغرفة الصوتية:** مبنية بوضع التناوب (شبه فوري). للترقية للايف الحقيقي
  استبدل منطق `voice_room_screen.dart` بمزود streaming — نقاط الوصل واضحة.
- **العلامة المائية:** أبقِ PerTh مفعّلة في الـ Space (متطلب قانوني للصوت المولّد).
- **الخط:** التطبيق يستخدم خط Cairo — أضف ملفات الخط في `assets/` أو استبدله
  بخط عربي آخر في `app_theme.dart`.

## الترخيص والامتثال
- Chatterbox: MIT — تجاري مسموح
- استنسخ فقط أصوات لديك إذن باستخدامها (صوت المستخدم نفسه)
- أفصح عن الصوت المولّد بالذكاء الاصطناعي حيث يتطلب القانون
