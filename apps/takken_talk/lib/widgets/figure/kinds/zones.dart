import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 領域図（サイトの fig/Zones.svelte）。縦軸×横軸のマス目を「耐火建築物」などの領域で塗り分ける。
/// - cells[行][列] に regions のキー。同じキーが隣り合うと境目の線を消す（階段状の境目がそのまま覚える形になる）
/// - 領域の名前は、その領域の1マス（at を指定すればそこ、なければ真ん中に近いマス）に1回だけ。隣のマスにはみ出してよい
/// - 列は均等の幅（サイトは table-layout: fixed）
class ZonesBody extends StatelessWidget {
  const ZonesBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  static const _groupColors = [Color(0xFFD9661F), Color(0xFF5D9C3C), Color(0xFF3D6AB0)];
  static const _tones = {'a': Color(0xFFF6D3D0), 'b': Color(0xFFD4E6F6), 'c': Color(0xFFE2D8F0), 'd': Color(0xFFFBE7C6)};
  static const _edge = Color(0x2E000000);

  @override
  Widget build(BuildContext context) {
    final rows = strs(raw['rows']);
    final colGroups = maps(raw['colGroups']).map((g) => (label: str(g['label']), cols: strs(g['cols']))).toList();
    final cols = [
      for (var gi = 0; gi < colGroups.length; gi++)
        for (var ci = 0; ci < colGroups[gi].cols.length; ci++) (label: colGroups[gi].cols[ci], first: ci == 0),
    ];
    final cells = (raw['cells'] is List ? raw['cells'] as List : const []).map(strs).toList();
    final regions = <String, ({String label, String tone, List<int>? at})>{};
    if (raw['regions'] is Map) {
      (raw['regions'] as Map).forEach((k, v) {
        final r = v is Map ? v : const {};
        final at = r['at'] is List && (r['at'] as List).length == 2 ? (r['at'] as List).map((e) => (e as num).toInt()).toList() : null;
        regions['$k'] = (label: str(r['label']), tone: str(r['tone']), at: at);
      });
    }
    final footnotes = strs(raw['footnotes']);
    String? key(int i, int j) => (i >= 0 && i < cells.length && j >= 0 && j < cells[i].length) ? cells[i][j] : null;

    // 領域の名前を書くマス
    final labelAt = <String, String>{};
    regions.forEach((k, r) {
      if (r.at != null) {
        labelAt['${r.at![0]},${r.at![1]}'] = k;
        return;
      }
      final pos = <(int, int)>[];
      for (var i = 0; i < cells.length; i++) {
        for (var j = 0; j < cells[i].length; j++) {
          if (cells[i][j] == k) pos.add((i, j));
        }
      }
      if (pos.isEmpty) return;
      final ci = pos.fold<double>(0, (s, p) => s + p.$1) / pos.length;
      final cj = pos.fold<double>(0, (s, p) => s + p.$2) / pos.length;
      double d(( int, int) p) => math.sqrt(math.pow(p.$1 - ci, 2) + math.pow(p.$2 - cj, 2));
      pos.sort((a, b) => d(a).compareTo(d(b)));
      labelAt['${pos[0].$1},${pos[0].$2}'] = k;
    });

    return LayoutBuilder(builder: (context, box) {
      const axisW = 5.2 * 13 + 10;
      final colW = cols.isEmpty ? 0.0 : (box.maxWidth - axisW) / cols.length;
      const paperEdge = BorderSide(color: Palette.paper, width: 3);

      final header = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _axis(str(raw['rowAxis']), str(raw['colAxis'])),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var gi = 0; gi < colGroups.length; gi++)
                        Container(
                          width: colW * colGroups[gi].cols.length,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(color: _groupColors[gi % 3], border: const Border(left: paperEdge)),
                          child: Text(colGroups[gi].label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final c in cols)
                          Container(
                            width: colW,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: Palette.fill,
                              border: Border(
                                left: c.first ? paperEdge : BorderSide.none,
                                right: const BorderSide(color: Palette.line),
                                bottom: const BorderSide(color: Palette.lineStrong),
                              ),
                            ),
                            child: Text(c.label.split('／').join('\n'), textAlign: TextAlign.center, style: const TextStyle(fontSize: fsSub, height: 1.4, fontWeight: FontWeight.w700, color: Palette.ink)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      Widget row(int i) {
        final labels = <Widget>[];
        final tds = <Widget>[];
        for (var j = 0; j < cols.length; j++) {
          final k = key(i, j);
          final reg = k == null ? null : regions[k];
          final first = cols[j].first;
          final nextFirst = j + 1 < cols.length && cols[j + 1].first;
          BorderSide side(bool same) => BorderSide(color: same ? Colors.transparent : _edge);
          tds.add(Container(
            width: colW,
            constraints: const BoxConstraints(minHeight: 40),
            decoration: BoxDecoration(
              color: _tones[reg?.tone] ?? Palette.paper,
              border: Border(
                top: side(key(i - 1, j) == k),
                bottom: side(key(i + 1, j) == k),
                left: first ? paperEdge : side(key(i, j - 1) == k),
                right: side(key(i, j + 1) == k && !nextFirst),
              ),
            ),
          ));
          if (reg != null && labelAt['$i,$j'] == k) {
            labels.add(Positioned(
              left: axisW + colW * j + colW / 2 - 150,
              width: 300,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(reg.label.split('／').join('\n'), textAlign: TextAlign.center, softWrap: false, style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700, color: Palette.ink)),
              ),
            ));
          }
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: axisW,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Palette.fill, border: Border(bottom: BorderSide(color: Palette.line))),
                    child: Text(i < rows.length ? rows[i] : '', textAlign: TextAlign.center, style: const TextStyle(fontSize: fsSub, height: 1.4, fontWeight: FontWeight.w700, color: Palette.ink)),
                  ),
                  ...tds,
                ],
              ),
            ),
            ...labels,
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          for (var i = 0; i < rows.length; i++) row(i),
          for (final f in footnotes) Padding(padding: const EdgeInsets.only(top: 6), child: Text(f, style: const TextStyle(fontSize: fsSub, height: 1.6, color: Palette.inkSoft))),
        ],
      );
    });
  }

  /// 左上の隅: 斜めの線で分け、右上に横軸の名前、左下に縦軸の名前
  Widget _axis(String rowAxis, String colAxis) => Container(
        width: 5.2 * 13 + 10,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(color: Palette.fill, border: Border.all(color: Palette.lineStrong)),
        child: CustomPaint(
          painter: const _Diagonal(),
          child: Stack(
            children: [
              Positioned(top: 3, right: 5, child: Text(colAxis, style: const TextStyle(fontSize: fsSub, height: 1.2, fontWeight: FontWeight.w700, color: Palette.ink))),
              Positioned(bottom: 3, left: 5, child: Text(rowAxis, style: const TextStyle(fontSize: fsSub, height: 1.2, fontWeight: FontWeight.w700, color: Palette.ink))),
            ],
          ),
        ),
      );
}

class _Diagonal extends CustomPainter {
  const _Diagonal();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), Paint()
      ..color = Palette.lineStrong
      ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_Diagonal oldDelegate) => false;
}
