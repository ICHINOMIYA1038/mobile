import 'package:flutter/material.dart';

// アナログな騒音計・EQメーターをモチーフにした配色。
// ブラス(真鍮)を主役に、静か=セージ、要注意=コーラルを状態色として使う。
const _brassLight = Color(0xFFB9792E);
const _brassDark = Color(0xFFE3A85B);
const _onBrassLight = Color(0xFFFBF3E7);
const _onBrassDark = Color(0xFF211B10);

const _paperLight = Color(0xFFEFEAE0);
const _surfaceLight = Color(0xFFFBF8F1);
const _surfaceContainerLight = Color(0xFFF2ECDF);
const _inkLight = Color(0xFF2B2820);
const _mutedLight = Color(0xFF7A7565);

const _inkDark = Color(0xFF17191E);
const _surfaceDark = Color(0xFF1F2229);
const _surfaceContainerDark = Color(0xFF262A32);
const _onInkDark = Color(0xFFECE8DE);
const _mutedDark = Color(0xFF9E9887);

const _sageLight = Color(0xFF4C7A63);
const _sageDark = Color(0xFF7FB89A);
const _coralLight = Color(0xFFB44F34);
const _coralDark = Color(0xFFE2795A);

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = isDark
      ? const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: _brassDark,
          onPrimary: _onBrassDark,
          secondary: _sageDark,
          onSecondary: _onBrassDark,
          tertiary: _coralDark,
          onTertiary: _onBrassDark,
          surface: _inkDark,
          onSurface: _onInkDark,
          surfaceContainerLow: _surfaceDark,
          surfaceContainerHighest: _surfaceContainerDark,
          outline: _mutedDark,
        )
      : const ColorScheme.light(
          brightness: Brightness.light,
          primary: _brassLight,
          onPrimary: _onBrassLight,
          secondary: _sageLight,
          onSecondary: _onBrassLight,
          tertiary: _coralLight,
          onTertiary: _onBrassLight,
          surface: _paperLight,
          onSurface: _inkLight,
          surfaceContainerLow: _surfaceLight,
          surfaceContainerHighest: _surfaceContainerLight,
          outline: _mutedLight,
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// 数値表示(dB・時間・周波数)に使う等幅フォントスタック。
/// 桁が揃うことで計器らしい信頼感を出す。
const monoFontFamilyFallback = <String>[
  'SF Mono',
  'Menlo',
  'Roboto Mono',
  'monospace',
];
