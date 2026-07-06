import 'package:flutter/material.dart';

/// ألوان تطبيق جسر — منقولة من الهوية الأصلية (تركوازي/كهرماني على كحلي داكن)
class AppColors {
  AppColors._();

  // خلفيات
  static const bg = Color(0xFF0E1116);
  static const card = Color(0xFF161B22);
  static const surface2 = Color(0xFF1C232D);

  // نصوص
  static const text = Color(0xFFE8ECF1);
  static const textDim = Color(0xFFC4CCD6);
  static const muted = Color(0xFF8B95A3);
  static const faint = Color(0xFF5A6573);

  // العلامة
  static const teal = Color(0xFF4FB6B2);
  static const tealDark = Color(0xFF3A8F8C);
  static const amber = Color(0xFFF2A65A);
  static const amberDark = Color(0xFFD98938);

  // حالات
  static const ok = Color(0xFF5BD6A5);
  static const danger = Color(0xFFE06C5B);
  static const dangerDark = Color(0xFFC4503F);

  // حدود
  static const border = Color(0xFF2A323D);

  // تدرجات
  static const tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDark],
  );
  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber, amberDark],
  );
  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [danger, dangerDark],
  );

  static Color tealSoft(double o) => teal.withOpacity(o);
  static Color amberSoft(double o) => amber.withOpacity(o);
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        secondary: AppColors.amber,
        surface: AppColors.card,
        error: AppColors.danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: 'Cairo',
      ),
      splashColor: AppColors.tealSoft(0.1),
      highlightColor: AppColors.tealSoft(0.06),
    );
  }
}

/// أنماط نصية موحّدة
class AppText {
  AppText._();
  static const h1 = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text);
  static const h2 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(
      fontSize: 15, height: 1.6, color: AppColors.text);
  static const bodyDim = TextStyle(
      fontSize: 15, height: 1.6, color: AppColors.textDim);
  static const label = TextStyle(fontSize: 11, color: AppColors.muted);
  static const caption = TextStyle(fontSize: 12, color: AppColors.muted);
}
