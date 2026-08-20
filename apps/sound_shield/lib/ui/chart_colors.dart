import 'package:flutter/material.dart';

/// チャート描画専用のトークン。テーマのColorSchemeに無い
/// グリッド線・面塗りの薄い塗り足しなどをまとめる。
class ChartColors {
  const ChartColors({
    required this.grid,
    required this.muted,
    required this.ink,
    required this.accent,
    required this.rangeFill,
    required this.areaFill,
    required this.surface,
  });

  factory ChartColors.of(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ChartColors(
      grid: isDark
          ? const Color(0x24ECE8DE)
          : const Color(0x242B2820),
      muted: isDark ? const Color(0xFF9E9887) : const Color(0xFF7A7565),
      ink: isDark ? const Color(0xFFECE8DE) : const Color(0xFF2B2820),
      accent: isDark ? const Color(0xFFE3A85B) : const Color(0xFFB9792E),
      rangeFill: isDark
          ? const Color(0x47E3A85B)
          : const Color(0x3DB9792E),
      areaFill: isDark
          ? const Color(0x1FE3A85B)
          : const Color(0x1AB9792E),
      surface: isDark ? const Color(0xFF1F2229) : const Color(0xFFFBF8F1),
    );
  }

  final Color grid;
  final Color muted;
  final Color ink;
  final Color accent;
  final Color rangeFill;
  final Color areaFill;
  final Color surface;
}
