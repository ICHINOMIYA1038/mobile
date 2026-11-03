import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 数直線。しきい値ごとに何が変わるか。目盛りの間は等間隔（実際の比ではなく、覚える順番を見せる）。
/// 狭いとき（480 未満）は縦のはしごにする
class ScaleBody extends StatelessWidget {
  const ScaleBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final unit = str(raw['unit']);
    final marks = maps(raw['marks']);
    final below = optStr(raw['below']);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 480;
      final items = <Widget>[
        if (below != null) _mark(wide: wide, below: true, value: const Text('未満', style: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w700, color: Palette.inkSoft)), label: below),
        for (final m in marks)
          _mark(
            wide: wide,
            value: Text.rich(TextSpan(children: [TextSpan(text: str(m['value'])), TextSpan(text: ' $unit', style: const TextStyle(fontSize: fsSub))]),
                style: const TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: Palette.ink)),
            label: str(m['label']),
            detail: optStr(m['detail']),
          ),
      ];
      if (!wide) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 8), items[i]]]);
      }
      Widget across(List<Widget> xs) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (var i = 0; i < xs.length; i++) ...[if (i > 0) const SizedBox(width: 3), Expanded(child: xs[i])]],
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 10,
            child: across([
              if (below != null) _seg(Palette.fillStrong),
              for (var i = 0; i < marks.length; i++) _seg(Palette.primary.withValues(alpha: 0.35 + 0.65 * (i + 1) / marks.length)),
            ]),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 3), Expanded(child: items[i])]])),
        ],
      );
    });
  }

  Widget _seg(Color color) => DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)));

  Widget _mark({required bool wide, bool below = false, required Widget value, required String label, String? detail}) => Container(
        padding: wide ? const EdgeInsets.only(left: 8) : const EdgeInsets.fromLTRB(10, 2, 0, 2),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: below ? Palette.lineStrong : Palette.primary, width: wide ? 2 : 4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            value,
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w700, color: Palette.ink)),
            if (detail != null) ...[const SizedBox(height: 2), Text(detail, style: const TextStyle(fontSize: fsSub, height: 1.5, color: Palette.inkSoft))],
          ],
        ),
      );
}
