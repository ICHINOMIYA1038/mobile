import 'package:flutter/material.dart';

/// 落ち着いた藍色。長時間の学習で目が疲れないよう彩度は抑えめにしている。
const _seed = Color(0xFF2F5D8A);

const maruColor = Color(0xFF2E7D5B);
const batsuColor = Color(0xFFB4453C);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

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
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    // 本文は問題文を読むためのもの。行間を広めにとって可読性を優先する。
    textTheme: Typography.material2021().black.apply(bodyColor: scheme.onSurface).copyWith(
          bodyLarge: TextStyle(fontSize: 18, height: 1.7, color: scheme.onSurface),
        ),
  );
}
