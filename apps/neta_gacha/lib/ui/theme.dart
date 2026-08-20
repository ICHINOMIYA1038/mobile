import 'package:flutter/material.dart';

// ガチャガチャ(カプセルトイ)モチーフのアクセントカラー。
// 明暗どちらの背景でも視認できるよう、十分な彩度を保つ。
const gachaOrange = Color(0xFFFF6B4A);
const liveViolet = Color(0xFF7C5CFF);
const warmCream = Color(0xFFFFF6E9);
const inkNavy = Color(0xFF2A2438);

/// カプセルの色。シチュエーションごとに順番に割り当てて使う(実物のガチャガチャの
/// 詰め合わせのように、隣り合うタイルが同じ色に揃わないよう意図的にバラけさせている)。
const kCapsuleColors = [
  Color(0xFFFF9B85), // コーラル
  Color(0xFF7FC8F8), // スカイブルー
  Color(0xFFFFA8C5), // ピンク
  Color(0xFF6FDDB9), // ミント
  Color(0xFFB79CF2), // ラベンダー
  Color(0xFFFFCB5C), // マスタード
  Color(0xFFFFB37A), // ピーチ
];

/// UI全体の丸ゴシック体。
const uiFontFamily = 'ZenMaruGothic';

/// 引いたお題を手書き風の付箋で見せるときだけ使うフォント。多用すると読みにくいため、
/// お題本文以外(ボタン・見出し・設定画面など)には使わない。
const handwritingFontFamily = 'Yomogi';

/// カード背景・ページ背景・本文の色のように、明暗で切り替える必要がある色。
class AppColors {
  const AppColors({
    required this.pageBackground,
    required this.cardBackground,
    required this.textPrimary,
    required this.textMuted,
    required this.paperBackground,
    required this.paperShadow,
    required this.dotPattern,
    required this.machineGlass,
  });

  final Color pageBackground;
  final Color cardBackground;
  final Color textPrimary;
  final Color textMuted;

  /// 付箋・チケット風カードの紙の色。
  final Color paperBackground;
  final Color paperShadow;

  /// 背景にうっすら敷くドット柄の色。
  final Color dotPattern;

  /// カプセルマシンのガラス部分の色。
  final Color machineGlass;

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static const light = AppColors(
    pageBackground: warmCream,
    cardBackground: Colors.white,
    textPrimary: inkNavy,
    textMuted: Color(0xFF8A8093),
    paperBackground: Color(0xFFFFFBF0),
    paperShadow: Color(0x33B08968),
    dotPattern: Color(0x14FF6B4A),
    machineGlass: Color(0x33FFFFFF),
  );

  static const dark = AppColors(
    pageBackground: Color(0xFF1C1826),
    cardBackground: Color(0xFF2E2740),
    textPrimary: Color(0xFFF3EDFF),
    textMuted: Color(0xFFA79CC0),
    paperBackground: Color(0xFF362C2A),
    paperShadow: Color(0x55000000),
    dotPattern: Color(0x1FFF9B85),
    machineGlass: Color(0x22FFFFFF),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: gachaOrange,
    brightness: brightness,
    primary: gachaOrange,
    secondary: liveViolet,
    surface: colors.cardBackground,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: uiFontFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.pageBackground,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w900,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(color: colors.textPrimary, height: 1.5),
      bodyMedium: TextStyle(color: colors.textPrimary, height: 1.5),
      bodySmall: TextStyle(color: colors.textMuted, height: 1.4),
      labelSmall: TextStyle(color: colors.textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.pageBackground,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: colors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gachaOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontFamily: uiFontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// 引いたお題本文に使う手書き風スタイル。
TextStyle handwritingStyle(
  BuildContext context, {
  double fontSize = 22,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) {
  return TextStyle(
    fontFamily: handwritingFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: 1.6,
    color: color ?? AppColors.of(context).textPrimary,
  );
}
