import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Login / sign-up screen: email+password and Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit(AuthState auth) {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    if (_isSignUp) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) return;
      auth.signUpWithEmail(email: email, password: pass, displayName: name);
    } else {
      auth.signInWithEmail(email: email, password: pass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              const Center(child: JisrLogo(size: 64)),
              const SizedBox(height: 20),
              const Text('جسر',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'أنشئ حسابك' : 'مرحباً بعودتك',
                style: AppText.bodyDim,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Name (sign-up only)
              if (_isSignUp) ...[
                _field(
                  controller: _nameCtrl,
                  hint: 'الاسم',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
              ],
              _field(
                controller: _emailCtrl,
                hint: 'البريد الإلكتروني',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _passCtrl,
                hint: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                obscure: true,
              ),
              const SizedBox(height: 20),

              // Submit
              if (auth.loading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.teal))
              else
                GestureDetector(
                  onTap: () => _submit(auth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: Text(_isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول',
                          style: const TextStyle(
                              color: AppColors.bg,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),

              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13),
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('أو', style: AppText.caption),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ]),
              const SizedBox(height: 16),

              // Google
              GestureDetector(
                onTap: auth.loading ? null : () => auth.signInWithGoogle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            Color(0xFF4285F4),
                            Color(0xFF34A853)
                          ]),
                        ),
                        child: const Center(
                            child: Text('G',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
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
              ),

              const SizedBox(height: 24),
              // Toggle sign-up / sign-in
              GestureDetector(
                onTap: () => setState(() {
                  _isSignUp = !_isSignUp;
                  auth.error = null;
                }),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: _isSignUp
                            ? 'لديك حساب؟ '
                            : 'ليس لديك حساب؟ ',
                        style: AppText.caption),
                    TextSpan(
                        text: _isSignUp ? 'سجّل الدخول' : 'أنشئ حساباً',
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.faint, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
