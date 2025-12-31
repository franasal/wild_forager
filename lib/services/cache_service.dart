import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _themeKey = 'theme_mode';

  static Future<ThemeMode> getThemeMode() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_themeKey);
    return (v == 'light') ? ThemeMode.light : ThemeMode.dark;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
