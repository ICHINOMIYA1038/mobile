import 'package:flutter/material.dart';

import '../models/review_state.dart';

// 正解・不正解の色は学習用に見やすいものを使用
const maruColor = Color(0xFF2E7D5B);
const batsuColor = Color(0xFFB4453C);

/// 合格グラフのマス目の色。解き進めるほど濃くなる。
Color masteryColor(ColorScheme scheme, MasteryLevel level) {
  return switch (level) {
    MasteryLevel.untouched => scheme.surfaceContainerHighest,
    MasteryLevel.needsReview => batsuColor.withValues(alpha: 0.55),
    MasteryLevel.learning => scheme.primary.withValues(alpha: 0.30),
    MasteryLevel.familiar => scheme.primary.withValues(alpha: 0.62),
    MasteryLevel.mastered => scheme.primary,
  };
}

/// 凡例やアクセシビリティで読み上げる、到達度の呼び名。
String masteryLabel(MasteryLevel level) {
  return switch (level) {
    MasteryLevel.untouched => '未学習',
    MasteryLevel.needsReview => '要復習',
    MasteryLevel.learning => '学習中',
    MasteryLevel.familiar => 'あと少し',
    MasteryLevel.mastered => '定着',
  };
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // Warm & Human デザインシステムに則った配色設計
  // Background: F9F7F4 (Warm Cream)
  // Primary: FF8A3D (Orange)
  // Text Primary: 433D39 (Dark Warm Grey)
  // Text Secondary: 8C8681
  // Card Radius: 20.0
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF8A3D),
    primary: const Color(0xFFFF8A3D),
    onPrimary: Colors.white,
    secondary: const Color(0xFFE88A4F),
    surface: isDark ? const Color(0xFF23211F) : const Color(0xFFF9F7F4),
    onSurface: isDark ? const Color(0xFFF1EDE9) : const Color(0xFF433D39),
    surfaceContainerLow: isDark ? const Color(0xFF2E2B29) : const Color(0xFFF1EDE9),
    surfaceContainerHighest: isDark ? const Color(0xFF3E3A37) : const Color(0xFFE8E2DC),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: (isDark ? Typography.material2021().white : Typography.material2021().black).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      bodyLarge: TextStyle(fontSize: 17, height: 1.8, color: scheme.onSurface, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 15, height: 1.7, color: scheme.onSurface, letterSpacing: 0.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scheme.onSurface),
      labelMedium: const TextStyle(fontSize: 12, color: Color(0xFF8C8681)),
      labelSmall: const TextStyle(fontSize: 11, color: Color(0xFF8C8681)),
    ),
  );
}
