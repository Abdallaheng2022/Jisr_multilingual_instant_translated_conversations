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

/// رابط سيرفر Modal. بعد `modal deploy` ستحصل على رابط مثل:
///   https://USERNAME--jisr-fastapi-app.modal.run
/// ضعه هنا بدل الرابط الافتراضي.
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://YOUR-MODAL-URL.modal.run',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // إنشاء الخدمات (كائن واحد يُشارك عبر التطبيق)
  final api = ApiService(baseUrl: kApiBaseUrl);
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
