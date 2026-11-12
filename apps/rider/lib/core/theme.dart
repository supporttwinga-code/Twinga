import 'package:flutter/material.dart';

class TwingaColors {
  static const Color blue = Color(0xFF0077F7);
  static const Color orange = Color(0xFFFF9A1F);
  static const Color ink = Color(0xFF14213D);
  static const Color background = Color(0xFFF5F9FF);
  static const Color veg = Color(0xFF1E9E4A);
  static const Color error = Color(0xFFD93025);
}

class TwingaTheme {
  static ThemeData light() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: TwingaColors.blue).copyWith(
      primary: TwingaColors.blue,
      secondary: TwingaColors.orange,
      error: TwingaColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TwingaColors.background,
    );
  }
}
