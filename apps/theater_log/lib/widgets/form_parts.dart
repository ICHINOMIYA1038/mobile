import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 記録の入力欄の部品。箱に入れず、罫線 1 本の上に書く

const fieldStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink);
const _hint = Color(0xFFA3A39D);

InputDecoration lineDecoration(String hint, {Widget? prefix, Widget? suffix, String? helper}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _hint),
  helperText: helper,
  helperStyle: const TextStyle(fontSize: 12, color: Palette.inkSoft),
  prefixIcon: prefix,
  prefixIconConstraints: const BoxConstraints(minWidth: 30),
  suffixIcon: suffix,
  filled: false,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(vertical: 12),
  border: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.5)),
  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.5)),
  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.sumi, width: 2.5)),
);

/// 欄の小見出し
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
  );
}

/// 押すと選ぶ画面が開く 1 行。入力欄と同じく下に罫線を引く
class LineRow extends StatelessWidget {
  const LineRow({super.key, required this.text, this.placeholder = false, this.icon, this.action, this.onTap, this.trailing});
  final String text;
  final bool placeholder;
  final IconData? icon;
  final String? action;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.ink, width: 1.5))),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: placeholder ? Palette.inkSoft : Palette.ink), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: placeholder ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _hint) : fieldStyle)),
          if (action != null) Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
          ?trailing,
        ],
      ),
    ),
  );
}

/// 前に入れた値の候補。入力欄を触っている間だけ出す（押しても入力欄から外れたことにしない）
class Suggestions extends StatelessWidget {
  const Suggestions({super.key, required this.values, required this.onPick, this.caption});
  final List<String> values;
  final ValueChanged<String> onPick;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return TextFieldTapRegion(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (caption != null) Text(caption!, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
            for (final v in values.take(6))
              InkWell(
                key: Key('suggest-$v'),
                onTap: () => onPick(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: Palette.ink), borderRadius: BorderRadius.circular(2)),
                  child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.ink)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ノートの罫線。少なくとも [lines] 本、書いた分だけ下まで引く
class RuledPainter extends CustomPainter {
  const RuledPainter({required this.lineHeight, required this.lines});
  final double lineHeight;
  final int lines;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    final last = Paint()
      ..color = Palette.ink
      ..strokeWidth = 1.5;
    final n = math.max(lines, (size.height / lineHeight).floor());
    for (var i = 1; i <= n; i++) {
      final y = i * lineHeight - 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i == n ? last : soft);
    }
  }

  @override
  bool shouldRepaint(RuledPainter old) => old.lineHeight != lineHeight || old.lines != lines;
}
