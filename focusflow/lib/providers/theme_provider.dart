import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

enum ThemePreference { system, light, dark, custom }

class ThemeProvider extends ChangeNotifier {
  ThemePreference _preference = ThemePreference.system;
  Color _customSeedColor = AppColors.primary;
  bool _isInitialized = false;

  ThemePreference get preference => _preference;
  Color get customSeedColor => _customSeedColor;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// Load theme settings from local storage
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load preference index
    final prefIndex = prefs.getInt('theme_preference') ?? 0;
    _preference = ThemePreference.values[prefIndex];

    // Load custom color
    final colorValue = prefs.getInt('theme_custom_color') ?? AppColors.primary.value;
    _customSeedColor = Color(colorValue);

    _isInitialized = true;
    notifyListeners();
  }

  /// Get the current ThemeData based on preference
  ThemeData getTheme(Brightness systemBrightness) {
    switch (_preference) {
      case ThemePreference.light:
        return AppTheme.lightTheme;
      case ThemePreference.dark:
        return AppTheme.darkTheme;
      case ThemePreference.custom:
        return AppTheme.customTheme(_customSeedColor, systemBrightness);
      case ThemePreference.system:
      default:
        return systemBrightness == Brightness.dark 
            ? AppTheme.darkTheme 
            : AppTheme.lightTheme;
    }
  }

  /// Set the theme preference and save to local storage
  Future<void> setPreference(ThemePreference pref) async {
    _preference = pref;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_preference', pref.index);
  }

  /// Set the custom seed color and save to local storage
  Future<void> setCustomColor(Color color) async {
    _customSeedColor = color;
    _preference = ThemePreference.custom;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_custom_color', color.value);
    await prefs.setInt('theme_preference', ThemePreference.custom.index);
  }
}
