import 'package:flutter/material.dart';

class Palette {
  static const paper = Color(0xFFF7F2E8);
  static const card = Color(0xFFFFFCF5);
  static const ink = Color(0xFF22262E);
  static const inkSoft = Color(0xFF666A70);
  static const navy = Color(0xFF1F2F4A);
  static const vermilion = Color(0xFFB83A26);
  static const line = Color(0xFFDCD4C3);
}

const titleFont = 'Hiragino Mincho ProN';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.navy, primary: Palette.navy, secondary: Palette.vermilion, surface: Palette.paper, onSurface: Palette.ink);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    appBarTheme: const AppBarTheme(backgroundColor: Palette.paper, foregroundColor: Palette.ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    chipTheme: const ChipThemeData(backgroundColor: Palette.card, selectedColor: Palette.navy, side: BorderSide(color: Palette.line), showCheckmark: false),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Palette.card, indicatorColor: Color(0xFFE6DFCF)),
    dividerColor: Palette.line,
  );
}
