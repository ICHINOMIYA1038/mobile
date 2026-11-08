import 'package:flutter/material.dart';

/// 色は歌舞伎の定式幕（黒・柿・萌葱）と、もぎりのハンコの朱から取る。朱はハンコと星にだけ使う
class Palette {
  static const paper = Color(0xFFF6F6F3);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF262626);
  static const inkSoft = Color(0xFF6B6B66);
  static const line = Color(0xFFDADAD4);

  /// 定式幕の三色
  static const sumi = Color(0xFF000000);
  static const kaki = Color(0xFFB4532A);
  static const moegi = Color(0xFF2E6B4E);

  /// ハンコの朱肉
  static const vermilion = Color(0xFFD0342C);

  /// 主な操作と見出しの色（以前の紺の役目）
  static const navy = sumi;
}

/// 見出しと数字の書体。iPhone に入っているヒラギノ角ゴを極太（W8）で使う（アプリに書体を入れず、容量を増やさない）。
/// 使うときは fontWeight: FontWeight.w800 を付ける
const displayFont = 'Hiragino Sans';

/// 公演名などの太字。小さくても読めるよう標準のゴシックにする
const titleFont = 'Hiragino Sans';

/// ハンコの中の文字。印らしく明朝にする
const sealFont = 'Hiragino Mincho ProN';

/// 定式幕の三色の縞。選んでいるものや画面の区切りの印に使う
class JoshikiStripe extends StatelessWidget {
  const JoshikiStripe({super.key, this.height = 4, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: width,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ColoredBox(color: Palette.sumi)),
        Expanded(child: ColoredBox(color: Palette.kaki)),
        Expanded(child: ColoredBox(color: Palette.moegi)),
      ],
    ),
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.sumi, primary: Palette.sumi, onPrimary: Colors.white, secondary: Palette.kaki, surface: Palette.paper, onSurface: Palette.ink);
  const corner = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: titleFont, fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.sumi,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Palette.line,
        shape: corner,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Palette.ink, shape: corner, side: const BorderSide(color: Palette.ink))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Palette.ink)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Palette.sumi, foregroundColor: Colors.white, shape: corner, elevation: 2),
    chipTheme: const ChipThemeData(backgroundColor: Palette.card, selectedColor: Palette.sumi, side: BorderSide(color: Palette.line), showCheckmark: false, shape: corner),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)), borderSide: BorderSide(color: Palette.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)), borderSide: BorderSide(color: Palette.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)), borderSide: BorderSide(color: Palette.sumi, width: 1.6)),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.moegi : Palette.line),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.card,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? Palette.sumi : Palette.inkSoft)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.sumi) : const TextStyle(fontSize: 11, color: Palette.inkSoft),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.sumi : Palette.card),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Palette.ink),
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.line)),
        shape: const WidgetStatePropertyAll(corner),
      ),
    ),
    dividerColor: Palette.line,
  );
}
