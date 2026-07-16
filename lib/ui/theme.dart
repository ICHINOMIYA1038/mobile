import 'package:flutter/material.dart';

import '../models/review_state.dart';

/// 落ち着いた藍色。長時間の学習で目が疲れないよう彩度は抑えめにしている。
const _seed = Color(0xFF2F5D8A);

const maruColor = Color(0xFF2E7D5B);
const batsuColor = Color(0xFFB4453C);

/// 合格グラフのマス目の色。解き進めるほど濃くなる。
///
/// 濃さだけで4段階を伝えるため、隣り合う段階の差がはっきり出る値を選んでいる。
/// 「直近で間違えた」だけは濃淡ではなく色相を変え、弱点として目に入るようにする。
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
