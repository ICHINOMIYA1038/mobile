import 'package:flutter/material.dart';

/// アプリ全体で使う色の役割。
///
/// ライト/ダークそれぞれの具体的な色は [AppColors.light] / [AppColors.dark] に
/// まとめてあり、画面側は役割名（`context.colors.textPrimary` など）でしか
/// 参照しない。ハードコードした白文字などを画面側に書かないことで、
/// 「入力中の文字が見えない」という既存アプリで多発していたバグを構造的に防ぐ。
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

  /// 結果カードの背景など、アクセントを帯びた面。
  final Color accentSurface;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// 濃い色の塗り面（ホーム画面のカテゴリカードの裏など）の上に乗る文字色。
  final Color onInk;

  /// 濃い色の塗り面そのもの。
  final Color ink;

  final Color accent;
  final Color accentSoft;
  final Color accentDeep;

  /// アクセント色の面の上に乗る、常に濃い文字・アイコン色。
  final Color onAccent;

  final Color border;
  final Color borderSoft;
  final Color borderStrong;

  /// カードの落ち影に使う基準色。
  final Color shadow;

  /// 背景に散らす装飾ドットの色。
  final Color dotPattern;

  /// 結果画面のきらめき等、遊び心のある差し色。
  final Color decorativeAccent;

  // 「魔女の羊皮紙・アンティーク占い師の手帳」がコンセプト。
  // 羊皮紙は本質的に明るい紙の色なので、システムのライト/ダーク設定に関わらず
  // 同じ1つの見た目(このparchmentパレット)で統一している
  // (light/darkが同一値なのは意図的。将来ダークテーマ対応が必要になった場合の
  // ためにフィールド自体は残してある)。
  static const light = AppColors(
    background: Color(0xFFEDE0C0),
    surface: Color(0xFFF5ECD6),
    surfaceAlt: Color(0xFFE4D4AC),
    accentSurface: Color(0xFFE3CBB8),
    textPrimary: Color(0xFF3A2818),
    textSecondary: Color(0xFF6B5638),
    textMuted: Color(0xFF8C7A5E),
    onInk: Color(0xFFF5ECD6),
    ink: Color(0xFF3A2818),
    accent: Color(0xFF7A2434),
    accentSoft: Color(0xFFA85060),
    accentDeep: Color(0xFF5C1A26),
    onAccent: Color(0xFFF5ECD6),
    border: Color(0xFFB99B62),
    borderSoft: Color(0xFFD4BE8E),
    borderStrong: Color(0xFF8A6D3F),
    shadow: Color(0xFF2A1D10),
    dotPattern: Color(0xFFB99B62),
    decorativeAccent: Color(0xFF9C7A3C),
  );

  static const dark = light;

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
