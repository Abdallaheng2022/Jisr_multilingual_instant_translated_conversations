import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/billing_service.dart';
import 'state/app_state.dart';
import 'state/translation_state.dart';
import 'screens/home_shell.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // إنشاء الخدمات (كائن واحد يُشارك عبر التطبيق)
  final api = ApiService(modalUrl: kModalUrl, groqKey: kGroqKey);
  final audio = AudioService();
  final billing = BillingService();

  runApp(JisrApp(api: api, audio: audio, billing: billing));
}

class JisrApp extends StatelessWidget {
  final ApiService api;
  final AudioService audio;
  final BillingService billing;

  const JisrApp({
    super.key,
    required this.api,
    required this.audio,
    required this.billing,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(api: api, billing: billing),
        ),
        ChangeNotifierProxyProvider<AppState, TranslationState>(
          create: (ctx) => TranslationState(
            api: api,
            audio: audio,
            appState: ctx.read<AppState>(),
          ),
          update: (ctx, appState, prev) =>
              prev ?? TranslationState(api: api, audio: audio, appState: appState),
        ),
      ],
      child: MaterialApp(
        title: 'جسر',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        // دعم العربية والاتجاه من اليمين لليسار
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

/// شاشة إقلاع تنتظر تهيئة الحالة
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }
    return const HomeShell();
  }
}
