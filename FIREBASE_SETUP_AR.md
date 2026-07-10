# إعداد Firebase لتطبيق جسر (المرحلة ١)

الكود جاهز، لكن Firebase يحتاج خطوات إعداد منك (لا يمكن أتمتتها لأنها تخص
حسابك). اتبع هذه الخطوات بالترتيب.

## ما يوفّره Firebase هنا
- **تسجيل الدخول بـ Google** (Firebase Auth)
- **قاعدة بيانات** لحفظ المستخدمين والتصحيحات (Firestore)
- **تخزين الصوت** لبيانات التدريب (Storage)

## التكلفة
Firebase **مجاني** في خطة Spark للبدايات:
- Firestore: 50,000 قراءة + 20,000 كتابة يومياً مجاناً
- Auth: مجاني بالكامل
- Storage: 5 جيجا مجاناً
كافٍ لآلاف المستخدمين قبل أي تكلفة.

---

## الخطوات

### 1) أنشئ مشروع Firebase
1. اذهب إلى https://console.firebase.google.com
2. **Add project** → سمّه "jisr" → أكمل

### 2) فعّل تسجيل Google
1. في المشروع: **Authentication → Get started**
2. **Sign-in method → Google → Enable**
3. اختر بريد الدعم، احفظ

### 3) فعّل Firestore
1. **Firestore Database → Create database**
2. اختر **Production mode**
3. اختر أقرب منطقة (مثلاً europe-west)
4. في **Rules**، الصق هذه القواعد (تحمي بيانات كل مستخدم):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // كل مستخدم يصل لبياناته فقط
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // التصحيحات: المستخدم ينشئ ويقرأ تصحيحاته
    match /corrections/{docId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    // ملخصات التعلّم
    match /learning_summaries/{docId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

### 4) فعّل Storage
1. **Storage → Get started** → Production mode → نفس المنطقة
2. في **Rules**:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /training_audio/{allPaths=**} {
      allow write: if request.auth != null;
      allow read: if false;  // الصوت للتدريب فقط، لا يُقرأ من التطبيق
    }
  }
}
```

### 5) اربط تطبيق Android
1. في نظرة عامة المشروع: أيقونة Android (**Add app**)
2. **Android package name:** `com.example.jisr`
   (نفس ما في الكود؛ إن غيّرته، طابقه)
3. حمّل ملف **`google-services.json`**
4. ضعه في مشروعك: `android/app/google-services.json`

### 6) أضف إعداد Gradle
هذا يتم تلقائياً عبر flutterfire، أو يدوياً:

في `android/build.gradle.kts` (أو build.gradle) — أضف:
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

في `android/app/build.gradle.kts`:
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

> **الأسهل:** ثبّت flutterfire CLI وشغّل أمراً واحداً يفعل كل هذا:
> ```bash
> dart pub global activate flutterfire_cli
> flutterfire configure
> ```
> يولّد `firebase_options.dart` ويربط كل شيء تلقائياً.

### 7) SHA-1 (مطلوب لتسجيل Google على أندرويد)
تسجيل Google يتطلب بصمة SHA-1:
```bash
cd android
./gradlew signingReport
```
انسخ SHA-1، وأضفه في Firebase: **Project settings → Your apps → Add fingerprint**

---

## بعد الإعداد
1. `flutter pub get`
2. `flutter run`
3. جرّب "المتابعة عبر Google"

إن نجح الدخول وظهرت بياناتك، فالمرحلة ١ تعمل. التصحيحات ستُحفظ تلقائياً
في Firestore مع تطبيق معايير الجودة.

## ملاحظة الخصوصية
الصوت يُرفع للتدريب **فقط** إذا فعّل المستخدم "المساهمة في التحسين".
بدون موافقته، يُحفظ النص المُصحّح فقط (بلا صوت).
