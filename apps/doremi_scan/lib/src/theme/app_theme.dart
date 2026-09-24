import 'package:flutter/material.dart';

/// アプリ配色。保育・ピアノ初心者向けに、五線の黒に映える温かいオレンジを基調にする。
/// スクリーンショット(ストア)でも背景をこのブランド色で統一する方針。
class AppColors {
  static const brand = Color(0xFFE8722C); // ドレミのふりがな色と揃える
  static const brandDark = Color(0xFFC85A17);
  static const ink = Color(0xFF2A2320);
  static const paper = Color(0xFFFBF7F1); // 楽譜の紙色
  static const surface = Color(0xFFFFFFFF);
  // 注記テキスト用。紙色(paper)の上で WCAG AA (4.5:1) を満たす濃さにする
  static const muted = Color(0xFF6E635A);
  static const line = Color(0xFFE7DDD0);
  static const good = Color(0xFF2E8B6F);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      fontFamily: 'Hiragino Sans',
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: AppColors.brandDark,
          side: const BorderSide(color: AppColors.brand),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
    );
  }
}
