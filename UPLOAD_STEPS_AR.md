# خطوات الرفع والإعداد

## ١) الرفع على GitHub

فُكّ `jisr-ondevice-ready.zip`، ثم **استبدل** هذه في مستودعك:

```
lib/            ← المجلد كاملاً (40 ملف)
pubspec.yaml
.github/workflows/build.yml
```

ثم:
```bash
git add -A
git commit -m "on-device free tier + google fix"
git push
```

### تحقّق بعد الرفع (مهم — تكرّرت مشكلة عدم وصول الملفات)
افتح هذه على GitHub في المتصفح وتأكد من وجود العلامة:

| الملف | ابحث عن |
|---|---|
| `lib/services/ondevice/` | المجلد موجود (6 ملفات) |
| `lib/state/translation_state.dart` | `onDevice.speak` |
| `lib/services/auth_service.dart` | `com.jisr.app://login-callback` |
| `pubspec.yaml` | `sherpa_onnx` |
| `.github/workflows/build.yml` | `--org com.jisr` |

---

## ٢) ربط Google (الخطوات الناقصة)

الكود جاهز. الناقص إعداد خارجي في مكانين:

### أ) Google Cloud Console
1. https://console.cloud.google.com → مشروع جديد
2. **OAuth consent screen** → External → املأ الاسم والبريد → احفظ
3. **Credentials → Create Credentials → OAuth client ID**
4. النوع: **Web application** ⚠️ (**ليس Android** — أشهر خطأ)
5. **Authorized redirect URIs** → أضف:
   ```
   https://YOUR-PROJECT.supabase.co/auth/v1/callback
   ```
6. انسخ **Client ID** و **Client Secret**

### ب) Supabase
1. **Authentication → Providers → Google** → **فعّله** ← هذا سبب خطأ
   `provider is not enabled`
2. الصق Client ID و Secret → احفظ
3. **Authentication → URL Configuration → Redirect URLs** → أضف:
   ```
   com.jisr.app://login-callback
   ```

---

## ٣) قواعد البيانات (إن لم تُشغّلها بعد)

في Supabase → SQL Editor، شغّل بالترتيب:
1. الجداول الأساسية + RLS (أرسلتها سابقاً)
2. `RECORDINGS_TABLE.sql`
3. `QUOTA_SERVER.sql`

وأنشئ buckets في Storage: `training` · `rooms` · `recordings` (كلها public).

---

## ٤) ⚠️ تنبيه: اسم الحزمة تغيّر

من `com.example.jisr` إلى **`com.jisr.app`**.

- `com.example` **مرفوض في Play Store** — كان لا بد من تغييره
- التطبيق الجديد **مختلف** عن المثبّت لديك → **احذف القديم تماماً** قبل
  تثبيت الجديد (لن يُحدّث فوقه)
- بعد النشر على Play Store **لا يمكن تغييره أبداً**

---

## ٥) بعد أول بناء ناجح

نماذج الجهاز (~150–250MB) تُنزّل مرة واحدة. يظهر شريط برتقالي في شاشة
الترجمة للمستخدم المجاني: **«نزّل ملفات اللغة مرة واحدة»** → يفتح شاشة
التنزيل. بعدها الترجمة المجانية تعمل على الهاتف بلا خادم.

### اختبار التوجيه
- **حساب مجاني**: ترجم → راقب الشبكة → **لا طلبات** إلى `modal.run` أو
  `api.groq.com`. الصوت يخرج بصوت جاهز.
- **حساب مشترك**: ترجم → الطلبات تذهب إلى Modal، والصوت **بنبرتك**.
