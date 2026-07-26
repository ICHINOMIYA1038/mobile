import 'package:flutter/material.dart';

// アクセントカラー(猫の毛色・アクセント)は明暗どちらでも同じ値を使う。
// 十分に彩度があり、明るい背景・暗い背景のどちらでも視認できるため。
const nekoOrange = Color(0xFFE8873A);
const nekoCream = Color(0xFFFFF8EF);
const labMint = Color(0xFF4FB286);
const inkBrown = Color(0xFF4A3B33);

/// カード背景・ページ背景・本文の色のように、明暗で切り替える必要がある色。
/// nekoOrange/labMintのようなアクセントカラーはここに含めず、そのまま使う。
class AppColors {
  const AppColors({
    required this.pageBackground,
    required this.cardBackground,
    required this.textPrimary,
  });

  final Color pageBackground;
  final Color cardBackground;
  final Color textPrimary;

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static const light = AppColors(
    pageBackground: nekoCream,
    cardBackground: Colors.white,
    textPrimary: inkBrown,
  );

  static const dark = AppColors(
    pageBackground: Color(0xFF241B15),
    cardBackground: Color(0xFF3A2E26),
    textPrimary: Color(0xFFF5E9DD),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: nekoOrange,
    brightness: brightness,
    primary: nekoOrange,
    secondary: labMint,
    surface: colors.cardBackground,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.pageBackground,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(color: colors.textPrimary, height: 1.4),
      bodyMedium: TextStyle(color: colors.textPrimary, height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.pageBackground,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: nekoOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
