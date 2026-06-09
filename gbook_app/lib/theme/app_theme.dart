// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

// ── Color palette ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary      = Color(0xFF1A6B3C);
  static const Color primaryLight = Color(0xFF2E8B57);
  static const Color primaryDark  = Color(0xFF0F4024);

  static const Color credit = Color(0xFF16A34A);
  static const Color debit  = Color(0xFFDC2626);

  static const Color green  = Color(0xFF16A34A);
  static const Color red    = Color(0xFFDC2626);
  static const Color orange = Color(0xFFF97316);
  static const Color blue   = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);

  static const Color grey      = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F4F6);
  static const Color divider   = Color(0xFFE5E7EB);
  // alias used by language_screen
  static const Color border    = Color(0xFFE5E7EB);

  static const Color background   = Color(0xFFF9FAFB);
  static const Color surface      = Colors.white;
  static const Color textPrimary  = Color(0xFF111827);
  static const Color textSecondary= Color(0xFF6B7280);
}

// ── AppTheme — keeps ALL old accessor names so existing screens compile ────────
class AppTheme {
  AppTheme._();

  // ── Core brand colours (used everywhere) ───────────────────────────────────
  static const Color primaryColor = AppColors.primary;
  static const Color creditColor  = AppColors.credit;
  static const Color debitColor   = AppColors.debit;

  // ── Static getters that old screens reference as AppTheme.xxx ──────────────
  // colour aliases
  static const Color primary       = AppColors.primary;
  static const Color credit        = AppColors.credit;
  static const Color debit         = AppColors.debit;
  static const Color background    = AppColors.background;
  static const Color surface       = AppColors.surface;
  static const Color textPrimary   = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color divider       = AppColors.divider;
  // aliases used by parties_screen / language_screen
  static const Color backgroundGrey = AppColors.lightGrey;
  static const Color accentRed      = AppColors.red;

  // ── ThemeData ───────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary:     AppColors.primary,
        onPrimary:   Colors.white,
        secondary:   AppColors.primaryLight,
        onSecondary: Colors.white,
        surface:     AppColors.surface,
        onSurface:   AppColors.textPrimary,
        error:       AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGrey,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.red, width: 1.5),
        ),
        labelStyle: TextStyle(color: AppColors.grey, fontSize: 14),
        hintStyle:  TextStyle(color: AppColors.grey, fontSize: 14),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.lightGrey,
        selectedColor: Color(0x261A6B3C), // primary 15 %
        labelStyle: TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}