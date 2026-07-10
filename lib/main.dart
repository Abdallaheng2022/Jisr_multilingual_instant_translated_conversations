import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/billing_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'state/app_state.dart';
import 'state/translation_state.dart';
import 'state/auth_state.dart';
import 'state/learning_state.dart';
import 'state/voice_note_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

/// رابط سيرفر Modal (للاستنساخ الصوتي). بعد `modal deploy`:
///   https://USERNAME--jisr-fastapi-app.modal.run
const kModalUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://deep-shopping-2022--jisr-fastapi-app.modal.run',
);

/// مفتاح Groq (للتفريغ الصوتي). مجاني من https://console.groq.com
/// مرّره عند البناء: --dart-define=GROQ_KEY=gsk_...
const kGroqKey = String.fromEnvironment('GROQ_KEY', defaultValue: '');

/// هل نجحت تهيئة Firebase؟ (يُحدَّد عند البدء)
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase — بمعالجة أخطاء حتى لا يتجمد التطبيق إن لم يُعّد بعد
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    // Firebase غير مُعّد — التطبيق يعمل لكن بلا تسجيل دخول/حفظ سحابي
    firebaseReady = false;
    debugPrint('تعذّرت تهيئة Firebase (سيعمل التطبيق بدونها): $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // إنشاء الخدمات
  final api = ApiService(modalUrl: kModalUrl, groqKey: kGroqKey);
  final audio = AudioService();
  final billing = BillingService();
  final auth = AuthService();
  final db = DatabaseService();

  runApp(JisrApp(
    api: api,
    audio: audio,
    billing: billing,
    auth: auth,
    db: db,
  ));
}

class JisrApp extends StatelessWidget {
  final ApiService api;
  final AudioService audio;
  final BillingService billing;
  final AuthService auth;
  final DatabaseService db;

  const JisrApp({
    super.key,
    required this.api,
    required this.audio,
    required this.billing,
    required this.auth,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // حالة المصادقة (الدخول + مزامنة المستخدم)
        ChangeNotifierProvider(
          create: (_) => AuthState(auth: auth, db: db),
        ),
        ChangeNotifierProvider(
          create: (_) => AppState(api: api, billing: billing),
        ),
        ChangeNotifierProvider(
          create: (_) => LearningState(db: db),
        ),
        ChangeNotifierProvider(
          create: (ctx) => VoiceNoteState(
            api: api,
            audio: audio,
            appState: ctx.read<AppState>(),
          ),
        ),
        ChangeNotifierProxyProvider<AppState, TranslationState>(
          create: (ctx) => TranslationState(
            api: api,
            audio: audio,
            appState: ctx.read<AppState>(),
            db: db,
          ),
          update: (ctx, appState, prev) =>
              prev ??
              TranslationState(
                  api: api, audio: audio, appState: appState, db: db),
        ),
      ],
      child: MaterialApp(
        title: 'جسر',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const _Bootstrap(),
      ),
    );
  }
}

/// شاشة إقلاع: تنتظر المصادقة، ثم تعرض الدخول أو التطبيق.
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    // إن لم تنجح تهيئة Firebase، ادخل التطبيق مباشرة (بلا تسجيل دخول)
    if (!firebaseReady) {
      return const HomeShell();
    }

    final auth = context.watch<AuthState>();
    final app = context.watch<AppState>();

    // اربط تفعيل الاشتراك بمزامنته مع Firebase (مرة واحدة)
    app.onSubscribed ??= (plan) {
      context.read<AuthState>().setSubscribed(plan);
    };

    // انتظار تهيئة المصادقة والحالة
    if (!auth.ready || !app.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    // غير مسجّل → شاشة الدخول
    if (!auth.isSignedIn) {
      return const LoginScreen();
    }

    // مسجّل → التطبيق
    return const HomeShell();
  }
}
