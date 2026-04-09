import 'package:flutter/material.dart';

class AppColors {
  // Light Theme - Sky Blue
  static const Color primary = Color(0xFF03A9F4); 
  static const Color secondary = Color(0xFFB3E5FC);
  static const Color background = Color(0xFFF1F8E9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF01579B); 
  static const Color textSecondary = Color(0xFF4FC3F7);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE1F5FE);
  static const Color error = Color(0xFFD32F2F);

  // Dark Theme - Deep/Dark Blue
  static const Color darkPrimary = Color(0xFF0277BD); // Deeper Blue
  static const Color darkSecondary = Color(0xFF01579B); // Very Dark Blue
  static const Color darkBackground = Color(0xFF010A0F);
  static const Color darkSurface = Color(0xFF02161E);
  static const Color darkTextPrimary = Color(0xFFE1F5FE);
  static const Color darkTextSecondary = Color(0xFF81D4FA);
  static const Color darkDivider = Color(0xFF01579B);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textSecondary),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.darkSecondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      background: AppColors.darkBackground,
      onBackground: AppColors.darkTextPrimary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    dividerColor: AppColors.darkDivider,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
      titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
    ),
  );

  /// Generates a custom theme based on a seed color
  static ThemeData customTheme(Color seedColor, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
    );
  }
}
