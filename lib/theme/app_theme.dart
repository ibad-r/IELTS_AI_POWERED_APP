import 'package:flutter/material.dart';

// ── Dark Auth Theme (ChatGPT-inspired) ────────────────────────────
class AppDark {
  static const Color bg       = Color(0xFF0D0D0D);
  static const Color surface  = Color(0xFF1A1A1A);
  static const Color surface2 = Color(0xFF242424);
  static const Color border   = Color(0xFF323232);
  static const Color accent   = Color(0xFFFFFFFF);
}

// ── Light Splash Theme ────────────────────────────────────────────
class AppColors {
  static const Color background   = Color(0xFFF5F6FA);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color accent       = Color(0xFF1A1A1A);
  static const Color accentLight  = Color(0xFFEEEEFF);
  static const Color accentSoft   = Color(0xFFDDDDFF);
  static const Color textPrimary  = Color(0xFF0F0F1A);
  static const Color textSecondary= Color(0xFF888899);
  static const Color textHint     = Color(0xFFBBBBCC);
  static const Color border       = Color(0xFFE8E8F0);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppDark.bg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        surface: AppDark.surface,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      useMaterial3: true,
    );
  }
}