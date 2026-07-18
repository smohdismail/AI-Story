import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  parchment,
  midnight,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark;

  AppThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme') ?? 'dark';
    _themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == themeString,
      orElse: () => AppThemeMode.dark,
    );
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode.name);
  }

  ThemeData getThemeData() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
        );
      case AppThemeMode.parchment:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFDF6E3), // Soft parchment color
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFD4C4A8),
            foregroundColor: Colors.black,
          ),
          cardColor: const Color(0xFFFFF9E6),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.brown,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        );
      case AppThemeMode.midnight:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate dark
          cardColor: const Color(0xFF1E293B),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        );
      case AppThemeMode.dark:
      default:
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
        );
    }
  }
}
