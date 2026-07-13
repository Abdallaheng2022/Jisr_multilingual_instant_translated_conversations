# إعداد تسجيل الدخول بـ Google — الدليل الكامل

الكود جاهز. المشكلة أن Google يحتاج إعداداً في **3 أماكن**، وإن نقصت
حلقة واحدة **لن يعمل إطلاقاً**.

## ⚠️ تغيير مهم: اسم الحزمة

غيّرت اسم الحزمة من `com.example.jisr` (مرفوض في Play Store!) إلى:

```
com.jisr.app
```

والـ deep link موحّد معه:
```
com.jisr.app://login-callback
```

استخدم هذه القيم بالضبط في الخطوات التالية.

---

## الخطوة ١: Google Cloud Console

### أ) أنشئ مشروعاً
1. اذهب إلى https://console.cloud.google.com
2. أنشئ مشروعاً جديداً (أو استخدم موجوداً)

### ب) أعدّ شاشة الموافقة (OAuth consent screen)
1. **APIs & Services → OAuth consent screen**
2. اختر **External**
3. املأ: اسم التطبيق (جسر)، بريد الدعم، بريد المطوّر
4. احفظ

### ج) أنشئ Client ID — نوع **Web** (مهم!)
1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **Web application** ← ليس Android!
3. **Authorized redirect URIs** → أضف:
   ```
   https://YOUR-PROJECT.supabase.co/auth/v1/callback
   ```
   (استبدل YOUR-PROJECT بمعرّف مشروعك في Supabase)
4. احفظ → **انسخ Client ID و Client Secret**

> **لماذا Web وليس Android؟** لأن Supabase هو من يتولى تبادل OAuth،
> لا التطبيق مباشرة. هذا أكثر خطأ شائع.

---

## الخطوة ٢: Supabase

1. **Authentication → Providers → Google**
2. فعّله (Enable)
3. الصق **Client ID** و **Client Secret** من الخطوة السابقة
4. احفظ

### أضف الـ Redirect URL
1. **Authentication → URL Configuration**
2. في **Redirect URLs**، أضف:
   ```
   com.jisr.app://login-callback
   ```
3. احفظ

---

## الخطوة ٣: التطبيق ✅ (جاهز)

- الـ deep link محقون تلقائياً في الـ workflow
- الكود يستخدم `com.jisr.app://login-callback`
- لا تحتاج فعل شيء هنا

---

## التحقق من نجاح الإعداد

بعد البناء، عند الضغط على "المتابعة عبر Google":
1. تُفتح صفحة Google لاختيار الحساب
2. بعد الاختيار، **يعود التطبيق تلقائياً** وأنت مسجّل الدخول

### إن لم يعد للتطبيق
→ الـ Redirect URL في Supabase ناقص أو خاطئ (الخطوة ٢)

### إن ظهر خطأ من Google
→ الـ redirect URI في Google Console خاطئ (الخطوة ١-ج)
→ تأكد أنه يشير لـ Supabase، لا للتطبيق

### إن لم تُفتح صفحة Google أصلاً
→ Google غير مُفعّل في Supabase (الخطوة ٢)

---

## ملاحظة عن Play Store

اسم الحزمة `com.jisr.app` صالح للنشر. لكن انتبه: **بعد النشر لا يمكن
تغييره أبداً** — فتأكد أنه الاسم الذي تريده قبل أول رفع.
