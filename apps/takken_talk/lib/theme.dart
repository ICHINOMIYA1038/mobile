import 'package:flutter/material.dart';

/// サイト（shikaku.pairof.jp）と同じ色。名前もサイトの CSS 変数（src/app.css）にそろえる。
class Palette {
  Palette._();
  static const paper = Color(0xFFFFFEFB);
  static const desk = Color(0xFFF2F4EF);
  static const ink = Color(0xFF1C2B24);
  static const inkSoft = Color(0xFF5C6B62);
  static const inkFaint = Color(0xFF8F9C94);
  static const line = Color(0xFFDDE3DB);
  static const lineStrong = Color(0xFFC0CABF);
  static const fill = Color(0xFFF1F4EF);
  static const fillStrong = Color(0xFFE3E9E1);
  static const primary = Color(0xFF2D5A47);
  static const primaryStrong = Color(0xFF1F4233);
  static const primarySoft = Color(0xFFE2EDE7);
  static const highlight = Color(0xFFF0D97A);
  static const highlightSoft = Color(0xFFFBF3D2);
  static const success = Color(0xFF2E7D4F);
  static const successSoft = Color(0xFFE3F2E8);
  static const danger = Color(0xFFC94F4F);
  static const dangerSoft = Color(0xFFFBEAEA);
  static const warning = Color(0xFFA8660A);
  static const warningSoft = Color(0xFFFCF0DC);
  static const ai = Color(0xFF6B5BB5);
  static const aiSoft = Color(0xFFEFEDF9);
  static const hanamaru = Color(0xFFE0413B);

  /// 図の列の色（サイトの --c1〜--c4）
  static const columns = [Color(0xFF2D5A47), Color(0xFF2F5F9E), Color(0xFF9A5B0C), Color(0xFF6B5BB5)];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.primary, primary: Palette.primary, surface: Palette.paper);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Palette.desk,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Palette.desk,
      foregroundColor: Palette.ink,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: Palette.line),
      ),
    ),
    dividerColor: Palette.line,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.7, color: Palette.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.7, color: Palette.ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Palette.primary, width: 1.5),
        foregroundColor: Palette.primary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Palette.paper, indicatorColor: Palette.primarySoft),
  );
}
