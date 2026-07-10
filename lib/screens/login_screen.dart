import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// شاشة تسجيل الدخول عبر Google
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: JisrLogo(size: 72)),
              const SizedBox(height: 24),
              const Text('جسر',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'ترجمة صوتية بصوتك، بسبع لغات',
                style: AppText.bodyDim,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (auth.loading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.teal))
              else
                _googleButton(context, auth),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              Text(
                'بتسجيلك توافق على حفظ بياناتك لتحسين تجربتك',
                style: TextStyle(color: AppColors.faint, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleButton(BuildContext context, AuthState auth) {
    return GestureDetector(
      onTap: () => auth.signInWithGoogle(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شعار Google (حرف G ملوّن مبسّط)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                ),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('المتابعة عبر Google',
                style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
