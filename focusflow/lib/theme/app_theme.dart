import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF466362); // Main accent
  static const Color secondary = Color(0xFFA3B9B1); // Complementary
  static const Color background = Color(
    0xFFF4F7F6,
  ); // Light background (updated)
  static const Color surface = Color(0xFFFFFFFF); // Card/modal surfaces
  static const Color error = Color(0xFFD9534F); // Error color
  static const Color textPrimary = Color(0xFF1F2A2A); // Main text (updated)
  static const Color textSecondary = Color(
    0xFF5F6F6F,
  ); // Secondary text (updated)
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Text on primary
  static const Color divider = Color(0xFFDDE5E4); // Divider/border (updated)
}

ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.textPrimary,
    background: AppColors.background,
    onBackground: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    onError: AppColors.surface,
  ),
  scaffoldBackgroundColor: AppColors.background,
  dividerColor: AppColors.divider,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textSecondary),
    titleLarge: TextStyle(color: AppColors.textPrimary),
  ),
);
