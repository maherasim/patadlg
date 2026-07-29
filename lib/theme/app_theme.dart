import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette — mirrors the web platform's Tailwind theme (resources/css/app.css)
/// exactly, so the mobile app and the web dashboard read as one system.
class AppColors {
  AppColors._();

  // Primary — violet, sampled from the platform logo's ring.
  static const primary50 = Color(0xFFEEF0FF);
  static const primary100 = Color(0xFFDDE1FE);
  static const primary400 = Color(0xFF8172F8);
  static const primary500 = Color(0xFF5F40F5);
  static const primary600 = Color(0xFF4B2CE0);
  static const primary700 = Color(0xFF3D22C4);
  static const primary800 = Color(0xFF2C1890);

  // Accent — pink, sampled from the logo's cap.
  static const accent100 = Color(0xFFFCE4F1);
  static const accent400 = Color(0xFFF17FC3);
  static const accent500 = Color(0xFFEF66B4);
  static const accent600 = Color(0xFFD6449A);

  // Semantic status colors.
  static const info = Color(0xFF0284C7);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);

  // Neutrals.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF5F7F6);
  static const border = Color(0xFFE2E8E4);
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF52616B);
  static const inkFaint = Color(0xFF94A3A0);

  /// Signature gradient used on splash/onboarding backgrounds — violet to pink,
  /// the same two hues the logo mark is built from.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary700, primary500, accent500],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        primary: AppColors.primary500,
        secondary: AppColors.accent500,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surfaceSubtle,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary600,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary600,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.inkMuted, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.inkFaint, fontSize: 14),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary500 : Colors.transparent,
        ),
      ),
    );
  }
}
