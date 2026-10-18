import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 流れ。番号の丸を縦の線でつなぎ、右に手順の名前と説明
class FlowBody extends StatelessWidget {
  const FlowBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final steps = maps(raw['steps']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          CustomPaint(
            painter: i < steps.length - 1 ? const _Rail() : null,
            child: Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.paper, border: Border.all(color: Palette.columns[0], width: 2)),
                    child: Text('${i + 1}', style: TextStyle(fontSize: fsSub, height: 1, fontWeight: FontWeight.w700, color: Palette.columns[0])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(children: numSpans(str(steps[i]['title'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (optStr(steps[i]['detail']) != null) TextSpan(text: '\n', style: subStyle, children: numSpans(steps[i]['detail'] as String)),
                      ]),
                      style: bodyStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 丸の下から次の丸までの線（サイトの li::before: left 12px, top 26px, bottom 2px）
class _Rail extends CustomPainter {
  const _Rail();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTRB(12, 26, 14, size.height - 2), Paint()..color = Palette.lineStrong);
  }

  @override
  bool shouldRepaint(_Rail oldDelegate) => false;
}
