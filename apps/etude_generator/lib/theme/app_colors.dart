import 'package:flutter/material.dart';

/// アプリ全体で使う色の役割。
///
/// ライト/ダークそれぞれの具体的な色は [AppColors.light] / [AppColors.dark] に
/// まとめてあり、画面側は役割名（`context.colors.textPrimary` など）でしか
/// 参照しない。こうしておくことで、色そのものを変えたくなったときに
/// このファイルだけを直せばよくなる。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accentSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onInk,
    required this.ink,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.onAccent,
    required this.border,
    required this.borderSoft,
    required this.borderStrong,
    required this.shadow,
    required this.dotPattern,
    required this.decorativeAccent,
  });

  /// 画面全体の背景。
  final Color background;

  /// カードなど、背景の上に乗る面。
  final Color surface;

  /// 選ばれていない選択肢など、surfaceよりわずかに沈んだ面。
  final Color surfaceAlt;

  /// 役アイコンの背景など、アクセントを帯びた面。
  final Color accentSurface;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// 「はじめる」ボタンや役カードの裏など、濃い色の塗り面の上に乗る文字色。
  final Color onInk;

  /// 濃い色の塗り面そのもの（ボタンの背景・役を伏せたカードなど）。
  final Color ink;

  final Color accent;
  final Color accentSoft;
  final Color accentDeep;

  /// アクセント色の面（ピンクの丸背景など）の上に乗る、常に濃い文字・アイコン色。
  /// アクセント色自体はライト/ダーク双方で明るめに保っているため、これは反転させない。
  final Color onAccent;

  final Color border;
  final Color borderSoft;
  final Color borderStrong;

  /// カードの落ち影に使う基準色。実際の濃さは呼び出し側で透明度を変えて使う。
  final Color shadow;

  /// タイトル画面などの背景に散らす、水玉模様の点の色。
  final Color dotPattern;

  /// タイトル画面の紙吹雪風の装飾帯など、遊び心のある差し色。
  final Color decorativeAccent;

  static const light = AppColors(
    background: Color(0xFFF5F0E8),
    surface: Color(0xFFFFFCF7),
    surfaceAlt: Color(0xFFF4EEE6),
    accentSurface: Color(0xFFF3DED9),
    textPrimary: Color(0xFF282528),
    textSecondary: Color(0xFF746D68),
    textMuted: Color(0xFF8D837D),
    onInk: Colors.white,
    ink: Color(0xFF282528),
    accent: Color(0xFFE18379),
    accentSoft: Color(0xFFE99A90),
    accentDeep: Color(0xFF9D554F),
    onAccent: Color(0xFF282528),
    border: Color(0xFFDED4CA),
    borderSoft: Color(0xFFE3D8CE),
    borderStrong: Color(0xFFBEB3AA),
    shadow: Color(0xFF201B18),
    dotPattern: Color(0xFFDDD5CB),
    decorativeAccent: Color(0xFFD8B99F),
  );

  static const dark = AppColors(
    background: Color(0xFF1D1917),
    surface: Color(0xFF2A2522),
    surfaceAlt: Color(0xFF332E2A),
    accentSurface: Color(0xFF4A332F),
    textPrimary: Color(0xFFF1EAE3),
    textSecondary: Color(0xFFC9BEB5),
    textMuted: Color(0xFF9C9088),
    onInk: Color(0xFF1D1917),
    ink: Color(0xFFEFE6DD),
    accent: Color(0xFFEE988B),
    accentSoft: Color(0xFFE2A199),
    accentDeep: Color(0xFFD98F82),
    onAccent: Color(0xFF241F1C),
    border: Color(0xFF463F3A),
    borderSoft: Color(0xFF3A342F),
    borderStrong: Color(0xFF5A5049),
    shadow: Color(0xFF000000),
    dotPattern: Color(0xFF3A342F),
    decorativeAccent: Color(0xFFA8875F),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? accentSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? onInk,
    Color? ink,
    Color? accent,
    Color? accentSoft,
    Color? accentDeep,
    Color? onAccent,
    Color? border,
    Color? borderSoft,
    Color? borderStrong,
    Color? shadow,
    Color? dotPattern,
    Color? decorativeAccent,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    accentSurface: accentSurface ?? this.accentSurface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    onInk: onInk ?? this.onInk,
    ink: ink ?? this.ink,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    accentDeep: accentDeep ?? this.accentDeep,
    onAccent: onAccent ?? this.onAccent,
    border: border ?? this.border,
    borderSoft: borderSoft ?? this.borderSoft,
    borderStrong: borderStrong ?? this.borderStrong,
    shadow: shadow ?? this.shadow,
    dotPattern: dotPattern ?? this.dotPattern,
    decorativeAccent: decorativeAccent ?? this.decorativeAccent,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      dotPattern: Color.lerp(dotPattern, other.dotPattern, t)!,
      decorativeAccent: Color.lerp(
        decorativeAccent,
        other.decorativeAccent,
        t,
      )!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
