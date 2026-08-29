import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Theme for rural shopkeeper UI — per design.md
class AppTheme {
  static ThemeData lightTheme() {
    final notoFont = GoogleFonts.notoSans();
    final notoDevanagari = GoogleFonts.notoSansDevanagari();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: notoFont.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.inkPrimary,
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: TextTheme(
        headlineSmall: notoFont.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.inkPrimary,
        ),
        titleLarge: notoFont.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.inkPrimary,
        ),
        titleMedium: notoFont.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.inkPrimary,
        ),
        bodyLarge: notoFont.copyWith(
          fontSize: 18,
          color: AppColors.inkPrimary,
        ),
        bodyMedium: notoFont.copyWith(
          fontSize: 16,
          color: AppColors.inkPrimary,
        ),
        bodySmall: notoFont.copyWith(
          fontSize: 14,
          color: AppColors.inkSoft,
        ),
        labelLarge: notoFont.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: Size(double.infinity, 56), // min touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: notoFont.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: Size(double.infinity, 56),
          side: BorderSide(color: AppColors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: notoFont.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        labelStyle: notoFont.copyWith(
          fontSize: 14,
          color: AppColors.inkPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: notoFont.copyWith(
          fontSize: 16,
          color: AppColors.inkSoft,
        ),
        hintStyle: notoFont.copyWith(
          fontSize: 16,
          color: AppColors.inkSoft,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inkSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: notoFont.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: notoFont.copyWith(
          fontSize: 12,
        ),
      ),
    );
  }
}
