import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 計算の手順。条件 → 式を1行ずつ → 答え。数字は桁がそろうように等幅の数字で
class CalcBody extends StatelessWidget {
  const CalcBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final given = maps(raw['given']);
    final steps = maps(raw['steps']);
    final answer = raw['answer'] is Map ? (raw['answer'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: _tabular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (given.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(8)),
              // dt と dd の2列（左の列は一番長い名前に合わせる）
              child: Table(
                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                children: [
                  for (final g in given)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 14, bottom: 2),
                        child: Text(str(g['label']), style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.inkSoft, fontFeatures: _tabular)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(str(g['value']), style: const TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w700, color: Palette.ink, fontFeatures: _tabular)),
                      ),
                    ]),
                ],
              ),
            ),
          for (var i = 0; i < steps.length; i++) _step(i, steps[i]),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Palette.primarySoft, borderRadius: BorderRadius.circular(8)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(str(answer['label']), style: const TextStyle(fontSize: fsBody, height: 1.6, fontWeight: FontWeight.w700, color: Palette.ink)),
                Text(str(answer['value']), style: const TextStyle(fontSize: 22, height: 1.4, fontWeight: FontWeight.w700, color: Palette.primaryStrong, fontFeatures: _tabular)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int i, Map<String, dynamic> s) => CustomPaint(
        painter: const _Dashed(),
        child: Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Palette.fillStrong, shape: BoxShape.circle),
                child: Text('${i + 1}', style: const TextStyle(fontSize: fsSub, height: 1, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(s['label']), style: const TextStyle(fontSize: fsLabel, height: 1.6, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: str(s['expr'])),
                        TextSpan(text: ' ${optStr(s['op']) ?? '='} ', style: const TextStyle(color: Palette.inkFaint)),
                        TextSpan(text: str(s['result']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      style: const TextStyle(fontSize: 16, height: 1.6, color: Palette.ink, fontFeatures: _tabular),
                    ),
                    if (optStr(s['note']) != null) Text(s['note'] as String, style: const TextStyle(fontSize: fsLabel, height: 1.6, color: Palette.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// 手順の下の点線（サイトの border-bottom: 1px dashed）
class _Dashed extends CustomPainter {
  const _Dashed();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Palette.line;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, size.height - 1, 3, 1), p);
    }
  }

  @override
  bool shouldRepaint(_Dashed oldDelegate) => false;
}
