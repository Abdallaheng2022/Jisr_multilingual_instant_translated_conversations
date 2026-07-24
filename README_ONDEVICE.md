# جسر — الطبقة المجانية على الجهاز (On-Device Free Tier)

يفصل هذا التحديث التطبيق إلى مسارين:

| الخطوة | المجاني (على الهاتف) | المدفوع (خادم) |
|---|---|---|
| التفريغ (STT) | Whisper — sherpa-onnx | Groq `whisper-large-v3` |
| تنظيف النص | Qwen3-0.6B *(اختياري، مُعطّل افتراضياً)* | — |
| الترجمة | MyMemory | MyMemory |
| النطق (TTS) | Piper — صوت جاهز | **Modal / Chatterbox — استنساخ صوته** |

**Modal لم يتغيّر إطلاقاً في الباقة المدفوعة.** نفس `ApiService.synthesize()`،
نفس `$modalUrl/tts`، نفس المهلات. أُضيف أمامه شرط واحد فقط:

```dart
appState.subscribed ? api.synthesize(...) : onDevice.speak(...)
```

النتيجة: المستخدم المجاني **لا يلمس Modal ولا Groq أبداً** → تكلفته ≈ صفر،
والاستنساخ يصبح ميزة الاشتراك الحقيقية.

---

## 1) الملفات

### جديدة
```
lib/services/ondevice/
├── model_manager.dart          # تنزيل/فكّ/تخزين النماذج + سجلّ الروابط
├── ondevice_tts_service.dart   # Piper (نطق)
├── ondevice_stt_service.dart   # Whisper (تفريغ)
├── ondevice_llm_service.dart   # Qwen3 (تنظيف — معطّل افتراضياً)
├── ondevice_voice.dart         # واجهة موحّدة تُحقن في الحالات
└── wav.dart                    # قراءة/كتابة WAV بلا مكتبات خارجية
lib/screens/model_download_screen.dart   # شاشة التنزيل المسبق
```

### مُعدّلة (انسخها فوق ملفاتك)
```
lib/main.dart                   # إنشاء OnDeviceVoice + حقنه في المزوّدات
lib/state/app_state.dart        # لا توقظ Modal للمجاني (refreshHealth)
lib/state/translation_state.dart
lib/state/voice_note_state.dart
lib/state/room_state.dart       # + appState و onDevice في الباني
```

> عُدّلت الملفات الخمسة انطلاقاً من نسختك الفعلية — الباقي فيها كما هو.

---

## 2) الحزم

```bash
flutter pub add sherpa_onnx archive
```

```yaml
dependencies:
  sherpa_onnx: ^1.10.0   # TTS + STT على الجهاز (ثبّت الأحدث)
  archive: ^3.6.1        # فكّ .tar.bz2 لنماذج sherpa
```

`http` و `path_provider` و `uuid` موجودة عندك أصلاً.

---

## 3) التشغيل

```bash
flutter pub get
flutter run --dart-define=GROQ_KEY=... --dart-define=API_BASE_URL=... \
            --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### التنزيل المسبق (مهم)
أول استخدام مجاني يحتاج ~150–250MB (Whisper + صوت لكل لغة). لا تتركه يحدث
فجأة أثناء الترجمة — افتح الشاشة بعد الدخول أو عند اختيار اللغات:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ModelDownloadScreen(
    onDevice: onDevice,
    langs: {appState.sourceLang.code, appState.targetLang.code},
  ),
));
```

---

## 4) الاختبار

1. **حساب مجاني** → اختر عربي ← تركي → نزّل النماذج → ترجم.
   تحقّق: لا طلب إلى `modal.run` ولا إلى `api.groq.com` (راقب Network).
   الصوت يخرج بصوت تركي جاهز.
2. **حساب مشترك** → نفس الخطوات → يجب أن يعود المسار إلى Modal
   ويخرج الصوت بنبرة المستخدم.
3. **وضع الطيران** بعد التنزيل: التفريغ والنطق يعملان؛ الترجمة وحدها
   تحتاج إنترنت (MyMemory) — انظر "الحدود" أدناه.

---

## 5) قبل الإطلاق — تحقّق من هذه

- **روابط النماذج**: راجع `OnDeviceModels` في `model_manager.dart`. أسماء
  الإصدارات على GitHub قد تتغيّر — افتح كل رابط وتأكد أنه يعمل، وأن `id`
  يطابق اسم المجلّد **داخل** الأرشيف بالضبط.
- **أسماء حقول sherpa_onnx**: تطابق ~1.10.x. إن ثبّتّ إصداراً أحدث وتغيّرت
  الأسماء، طابقها مع `OfflineTtsVitsModelConfig` و `OfflineWhisperModelConfig`
  في نسختك.
- **جودة اللهجات**: Whisper-base أضعف من `whisper-large-v3` مع العامية.
  إن كانت الدقة غير كافية، بدّل إلى `whisperSmall` في `model_manager.dart`
  (سطر واحد) — الحجم يرتفع إلى ~240MB.
- **الترجمة ما زالت شبكية**: MyMemory يعمل للطرفين. إن أردت وضعاً غير متصل
  بالكامل، ستحتاج نموذج ترجمة على الجهاز (مثل NLLB/Marian) — خارج نطاق
  هذه الحزمة.
- **تنظيف النص (LLM)**: مُعطّل. 0.6B يضيف ثوانٍ على هاتف متوسط. للتفعيل:
  أضف حزمة llama.cpp، نفّذ `_infer` في `ondevice_llm_service.dart`، ثم
  `OnDeviceVoice(enableLlmCleanup: true)` في `main.dart`.
- **الذاكرة**: يُحمَّل محرّك واحد لكل نوع فقط، ويُفرّغ تلقائياً عند تغيير
  اللغة. عند ضغط الذاكرة نادِ `onDevice.unloadAll()`.
- **الغرفة الصوتية**: المجاني الآن يُسمع الطرف الآخر بصوت جاهز لا بنبرته.
  إن أردت حماية قيمة الاشتراك أكثر، اجعل الغرفة للمشتركين فقط بدل ذلك.

---

## 6) أثر التكلفة

كان في `SCALING_GUIDE_AR.md`: ‏10,000 مستخدم مجاني ≈ ‎$130/شهر‎ (Modal + Groq).
بعد هذا التحديث المجاني لا يستدعي أياً منهما — تبقى فقط استضافة ملفات
النماذج (ثابتة، وقابلة للوضع على CDN مجاني). Modal يعمل فقط لمن يدفع.
