import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 時間の流れ。出来事を縦に並べ、あいだに「8日以内」のような期間を札で出す
class TimelineBody extends StatelessWidget {
  const TimelineBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final events = maps(raw['events']);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < events.length; i++) _event(events[i], last: i == events.length - 1),
        ],
      ),
    );
  }

  Widget _event(Map<String, dynamic> e, {required bool last}) {
    final em = e['emphasis'] == true;
    final gap = last ? null : optStr(e['gap']);
    return CustomPaint(
      painter: _Axis(line: !last, emphasis: em),
      child: Padding(
        padding: const EdgeInsets.only(left: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: str(e['label']), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: em ? Palette.primary : Palette.ink)),
                  if (optStr(e['detail']) != null) TextSpan(text: '\n${e['detail']}', style: const TextStyle(fontSize: fsLabel, color: Palette.inkSoft)),
                ]),
                style: const TextStyle(height: 1.6, color: Palette.ink),
              ),
            ),
            if (gap != null)
              Transform.translate(
                offset: const Offset(-4, 0),
                child: Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                  decoration: BoxDecoration(color: Palette.highlightSoft, border: Border.all(color: Palette.highlight), borderRadius: BorderRadius.circular(999)),
                  child: Text(gap, style: const TextStyle(fontSize: fsLabel, height: 1.5, fontWeight: FontWeight.w700, color: Palette.ink)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 時間の軸と点（サイトの Timeline.svelte: 軸 left 7 / 幅 3、点 15px・枠 3px、強調は塗りと淡い輪）
class _Axis extends CustomPainter {
  const _Axis({required this.line, required this.emphasis});
  final bool line;
  final bool emphasis;

  @override
  void paint(Canvas canvas, Size size) {
    if (line) canvas.drawRect(Rect.fromLTRB(7, 14, 10, size.height + 6), Paint()..color = Palette.fillStrong);
    const c = Offset(8.5, 13.5);
    if (emphasis) {
      canvas.drawCircle(c, 7.5 + 4, Paint()..color = Palette.primarySoft);
      canvas.drawCircle(c, 7.5, Paint()..color = Palette.primary);
    } else {
      canvas.drawCircle(c, 7.5, Paint()..color = Palette.paper);
      canvas.drawCircle(c, 6, Paint()
        ..color = Palette.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_Axis old) => old.line != line || old.emphasis != emphasis;
}
