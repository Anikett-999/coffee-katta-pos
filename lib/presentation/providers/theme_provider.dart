import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  static const _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // System standardized on white (light) theme by default
    state = ThemeMode.light;
    await prefs.setString(_themeKey, 'light');
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    // Dark theme is currently restricted and upcoming
    state = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, 'light');
  }

  Future<void> setSystemTheme() async {
    state = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, 'light');
  }
}
