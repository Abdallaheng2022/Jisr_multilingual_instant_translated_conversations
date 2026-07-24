import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/billing_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/ondevice/ondevice_voice.dart';
import 'services/room_service.dart';
import 'state/app_state.dart';
import 'state/translation_state.dart';
import 'state/auth_state.dart';
import 'state/learning_state.dart';
import 'state/voice_note_state.dart';
import 'state/room_state.dart';
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

/// Supabase credentials — from your project settings (Settings → API).
/// Pass at build: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const kSupabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

/// Did Supabase initialize successfully?
bool backendReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — with a timeout so the app never hangs
  try {
    if (kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
      ).timeout(const Duration(seconds: 5));
      backendReady = true;
    }
  } catch (e) {
    backendReady = false;
    debugPrint('Supabase init failed (app runs without it): $e');
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
  final roomService = RoomService();

  // محرّكات الجهاز للطبقة المجانية (Whisper + Piper، وتنظيف LLM اختياري)
  // enableLlmCleanup: false افتراضياً — فعّله بعد قياس السرعة على جهاز حقيقي
  final onDevice = OnDeviceVoice(enableLlmCleanup: false);

  runApp(JisrApp(
    api: api,
    audio: audio,
    billing: billing,
    auth: auth,
    db: db,
    roomService: roomService,
    onDevice: onDevice,
  ));
}

class JisrApp extends StatelessWidget {
  final ApiService api;
  final AudioService audio;
  final BillingService billing;
  final AuthService auth;
  final DatabaseService db;
  final RoomService roomService;
  final OnDeviceVoice onDevice;

  const JisrApp({
    super.key,
    required this.api,
    required this.audio,
    required this.billing,
    required this.auth,
    required this.db,
    required this.roomService,
    required this.onDevice,
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
          create: (_) => AppState(api: api, billing: billing, db: db),
        ),
        ChangeNotifierProvider(
          create: (_) => LearningState(db: db),
        ),
        ChangeNotifierProvider(
          create: (ctx) => RoomState(
            api: api,
            audio: audio,
            rooms: roomService,
            appState: ctx.read<AppState>(),
            onDevice: onDevice,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => VoiceNoteState(
            api: api,
            audio: audio,
            appState: ctx.read<AppState>(),
            onDevice: onDevice,
          ),
        ),
        ChangeNotifierProxyProvider<AppState, TranslationState>(
          create: (ctx) => TranslationState(
            api: api,
            audio: audio,
            appState: ctx.read<AppState>(),
            db: db,
            onDevice: onDevice,
          ),
          update: (ctx, appState, prev) =>
              prev ??
              TranslationState(
                  api: api,
                  audio: audio,
                  appState: appState,
                  db: db,
                  onDevice: onDevice),
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
    // إن لم تنجح تهيئة الخادم، ادخل التطبيق مباشرة (بلا تسجيل دخول)
    if (!backendReady) {
      return const HomeShell();
    }

    final auth = context.watch<AuthState>();
    final app = context.watch<AppState>();

    // اربط تفعيل الاشتراك بمزامنته مع الخادم (مرة واحدة)
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

    // مسجّل → اجلب رصيده الحقيقي من الخادم (مرة واحدة)
    final uid = auth.user?.uid;
    if (uid != null && app.currentUserId != uid) {
      // بعد اكتمال البناء لتجنّب notifyListeners أثناء build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        app.syncQuotaFromServer(uid);
      });
    }

    // مسجّل → التطبيق
    return const HomeShell();
  }
}
