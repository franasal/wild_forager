import 'package:flutter/material.dart';

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF1A8F3F),
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF7EE787),
    useMaterial3: true,
  );
}
