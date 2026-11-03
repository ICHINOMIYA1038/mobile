import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 関係図（サイトの fig/Relation.svelte）。人を格子に並べ、矢印で「売った」「代理した」などを結ぶ。
/// サイトの SVG と同じ座標（格子 150×112、人の箱 116×58）で描き、幅に合わせて縮める（最大 560）。
/// 位置は教材で決める（自動で並べると、毎回ちがう形になって覚えにくいため）
class RelationBody extends StatelessWidget {
  const RelationBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final actors = maps(raw['actors'])
        .map((a) => _Actor(id: str(a['id']), name: str(a['name']), role: optStr(a['role']), x: (a['x'] as num?)?.toDouble() ?? 0, y: (a['y'] as num?)?.toDouble() ?? 0))
        .toList();
    final ids = {for (final a in actors) a.id};
    final links = maps(raw['links'])
        .where((l) => ids.contains(l['from']) && ids.contains(l['to']))
        .map((l) => _Link(from: str(l['from']), to: str(l['to']), label: str(l['label']), order: (l['order'] as num?)?.toInt(), tone: optStr(l['tone']) ?? 'main'))
        .toList();
    final verdict = optStr(raw['verdict']);
    final base = DefaultTextStyle.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actors.isNotEmpty)
          LayoutBuilder(builder: (context, c) {
            final g = _Geometry(actors, links);
            final w = math.min(c.maxWidth, 560.0);
            return Center(
              child: SizedBox(
                width: w,
                height: g.h * w / g.w,
                child: Semantics(
                  label: links.map((l) => '${g.byId[l.from]!.name}から${g.byId[l.to]!.name}へ ${l.label}').join('、'),
                  child: CustomPaint(painter: _RelationPainter(g, base)),
                ),
              ),
            );
          }),
        if (verdict != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Palette.successSoft, borderRadius: BorderRadius.circular(6)),
            child: Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: Palette.success, borderRadius: BorderRadius.circular(999)),
                    child: const Text('結論', style: TextStyle(fontSize: fsSub, height: 1.5, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                ...numSpans(verdict),
              ]),
              style: const TextStyle(fontSize: fsBody, height: 1.7, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ),
      ],
    );
  }
}

class _Actor {
  const _Actor({required this.id, required this.name, this.role, required this.x, required this.y});
  final String id, name;
  final String? role;
  final double x, y;
}

class _Link {
  const _Link({required this.from, required this.to, required this.label, this.order, required this.tone});
  final String from, to, label, tone;
  final int? order;
}

typedef _Box = ({double x0, double y0, double x1, double y1});

/// 座標の計算（サイトの geom / placed をそのまま移したもの）
class _Geometry {
  _Geometry(this.actors, this.links)
      : byId = {for (final a in actors) a.id: a},
        w = (actors.map((a) => a.x).reduce(math.max) + 1) * cw,
        h = (actors.map((a) => a.y).reduce(math.max) + 1) * ch {
    _place();
  }

  static const cw = 150.0, ch = 112.0, bw = 116.0, bh = 58.0, lh = 28.0;
  final List<_Actor> actors;
  final List<_Link> links;
  final Map<String, _Actor> byId;
  final double w, h;
  final edges = <({Offset a, Offset b})>[];
  final labels = <({Offset c, double w})>[];

  static Offset center(_Actor a) => Offset(a.x * cw + cw / 2, a.y * ch + ch / 2);

  /// 箱の縁から縁へ。行きと帰りがあるときは少しずらす
  ({Offset a, Offset b, Offset m}) _geom(_Link l) {
    final a = center(byId[l.from]!);
    final b = center(byId[l.to]!);
    final d = b - a;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final ux = d.dx / len, uy = d.dy / len;
    double nz(double v) => v == 0 ? 1e-9 : v;
    final e = math.min((bw / 2 / nz(ux)).abs(), (bh / 2 / nz(uy)).abs()) + 6;
    final twin = links.any((o) => o.from == l.to && o.to == l.from);
    final off = twin ? 9.0 : 0.0;
    final o = Offset(-uy * off, ux * off);
    final p1 = Offset(a.dx + ux * e, a.dy + uy * e) + o;
    final p2 = Offset(b.dx - ux * e, b.dy - uy * e) + o;
    return (a: p1, b: p2, m: (p1 + p2) / 2 + o * 1.6);
  }

  static double labelWidth(String s) => math.min(190, s.length * 16 + 18);

  /// ラベルの置き場所。矢印の先・人の箱・先に置いたラベルと重ならない位置を、線に沿ってずらす → 線の横に逃がす の順で探す
  void _place() {
    bool hit(_Box a, _Box b) => a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
    final actorBoxes = [
      for (final a in actors) (x0: center(a).dx - bw / 2, y0: center(a).dy - bh / 2, x1: center(a).dx + bw / 2, y1: center(a).dy + bh / 2),
    ];
    final taken = <_Box>[];
    for (final l in links) {
      final g = _geom(l);
      edges.add((a: g.a, b: g.b));
      final lw = labelWidth(l.label) + (l.order != null ? 22 : 0);
      final d = g.b - g.a;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final nx = -d.dy / len, ny = d.dx / len;
      final tips = <_Box>[
        (x0: g.b.dx - 9, y0: g.b.dy - 9, x1: g.b.dx + 9, y1: g.b.dy + 9),
        (x0: g.a.dx - 5, y0: g.a.dy - 5, x1: g.a.dx + 5, y1: g.a.dy + 5),
      ];
      Offset clamp(double x, double y) => Offset(math.min(math.max(x, lw / 2 + 2), w - lw / 2 - 2), math.min(math.max(y, lh / 2 + 2), h - lh / 2 - 2));
      var best = clamp(g.m.dx, g.m.dy);
      search:
      for (final off in const [0.0, 1.0, -1.0, 1.8, -1.8]) {
        for (final t in const [0.5, 0.42, 0.34, 0.58]) {
          final p = clamp(g.a.dx + d.dx * t + nx * off * (lh / 2 + 6), g.a.dy + d.dy * t + ny * off * (lh / 2 + 6));
          final box = (x0: p.dx - lw / 2, y0: p.dy - lh / 2, x1: p.dx + lw / 2, y1: p.dy + lh / 2);
          if (tips.any((b) => hit(box, b)) || actorBoxes.any((b) => hit(box, b)) || taken.any((b) => hit(box, b))) continue;
          best = p;
          break search;
        }
      }
      taken.add((x0: best.dx - lw / 2, y0: best.dy - lh / 2, x1: best.dx + lw / 2, y1: best.dy + lh / 2));
      labels.add((c: best, w: lw));
    }
  }
}

class _RelationPainter extends CustomPainter {
  _RelationPainter(this.g, this.base);
  final _Geometry g;
  final TextStyle base;

  static Color _tone(String t) => switch (t) { 'sub' => Palette.inkFaint, 'ng' => Palette.danger, _ => Palette.primary };

  /// 文字を c を中心に置く（幅 maxW に入らなければ縮める）
  void _text(Canvas canvas, String s, Offset c, TextStyle style, {double? maxW}) {
    var tp = TextPainter(text: TextSpan(text: s, style: base.merge(style)), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    if (maxW != null && tp.width > maxW) {
      final fs = (style.fontSize ?? 14) * maxW / tp.width;
      tp.dispose();
      tp = TextPainter(text: TextSpan(text: s, style: base.merge(style.copyWith(fontSize: fs))), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    }
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p, double on, double off) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final u = d / len;
    for (double s = 0; s < len; s += on + off) {
      canvas.drawLine(a + u * s, a + u * math.min(s + on, len), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / g.w);

    // 矢印
    for (var i = 0; i < g.links.length; i++) {
      final l = g.links[i];
      final e = g.edges[i];
      final color = _tone(l.tone);
      final p = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      // 矢じりの根元まで線を引く（サイトの marker は線の先に 7×2.5 の大きさで付く）
      final d = e.b - e.a;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final u = d / len;
      const head = 17.5;
      final end = e.b - u * (head * 0.9);
      switch (l.tone) {
        case 'sub':
          _dashed(canvas, e.a, end, p, 6, 5);
        case 'ng':
          _dashed(canvas, e.a, end, p, 3, 4);
        default:
          canvas.drawLine(e.a, end, p);
      }
      final n = Offset(-u.dy, u.dx);
      final tip = e.b + u * (head * 0.1);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - u * head + n * head / 2).dx, (tip - u * head + n * head / 2).dy)
          ..lineTo((tip - u * head - n * head / 2).dx, (tip - u * head - n * head / 2).dy)
          ..close(),
        Paint()..color = color,
      );
    }

    // 人の箱
    for (final a in g.actors) {
      final c = _Geometry.center(a);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: _Geometry.bw, height: _Geometry.bh), const Radius.circular(10));
      canvas.drawRRect(r, Paint()..color = Palette.paper);
      canvas.drawRRect(r, Paint()
        ..color = Palette.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      const nameStyle = TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w700, color: Palette.ink);
      if (a.role != null) {
        _text(canvas, a.name, c.translate(0, -11), nameStyle, maxW: _Geometry.bw - 8);
        _text(canvas, a.role!, c.translate(0, 13), const TextStyle(fontSize: 14, height: 1.2, color: Palette.inkSoft), maxW: _Geometry.bw - 6);
      } else {
        _text(canvas, a.name, c, nameStyle, maxW: _Geometry.bw - 8);
      }
    }

    // ラベル（矢印の上に重ねる）
    for (var i = 0; i < g.links.length; i++) {
      final l = g.links[i];
      final pl = g.labels[i];
      final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: pl.c, width: pl.w, height: _Geometry.lh), const Radius.circular(14));
      canvas.drawRRect(rect, Paint()..color = Palette.paper);
      canvas.drawRRect(rect, Paint()
        ..color = switch (l.tone) { 'main' => Palette.primary, 'ng' => Palette.danger, _ => Palette.lineStrong }
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      final left = pl.c.dx - pl.w / 2;
      if (l.order != null) {
        canvas.drawCircle(Offset(left + 15, pl.c.dy), 9.5, Paint()..color = Palette.primary);
        _text(canvas, '${l.order}', Offset(left + 15, pl.c.dy), const TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white));
      }
      final textW = pl.w - (l.order != null ? 22 : 0) - 12;
      _text(canvas, l.label, Offset(pl.c.dx + (l.order != null ? 11 : 0), pl.c.dy), const TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w700, color: Palette.ink), maxW: textW);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RelationPainter old) => old.g != g;
}
