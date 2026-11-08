import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 挿絵。画風は「ゴム印の線画」（docs/illustration-style.md）。
/// 墨の線は 1 種類の太さで角を立て、朱は塗りだけに使う。座標は 120×100 の枠で描き、置く大きさに合わせて縮める
abstract class _LineArt extends CustomPainter {
  const _LineArt();

  static const _w = 120.0, _h = 100.0;

  /// 線の太さ（120×100 の枠での値）
  static const stroke = 2.2;

  Paint get ink => Paint()
    ..color = Palette.sumi
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.butt;
  Paint get shu => Paint()..color = Palette.vermilion;

  void draw(Canvas canvas);

  /// 朱で塗り、墨で縁取る
  void shuShape(Canvas canvas, Path p) => canvas
    ..drawPath(p, shu)
    ..drawPath(p, ink);

  /// 下向きに波打つ幕の裾（一文字幕）
  Path scallop(double x0, double x1, double y, double depth, double step) {
    final p = Path()
      ..moveTo(x0, y - depth - 6)
      ..lineTo(x1, y - depth - 6)
      ..lineTo(x1, y);
    for (var x = x1; x > x0 + 0.1; x -= step) {
      p.quadraticBezierTo(x - step / 2, y + depth, x - step, y);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = (size.width / _w) < (size.height / _h) ? size.width / _w : size.height / _h;
    canvas.save();
    canvas.translate((size.width - _w * k) / 2, (size.height - _h * k) / 2);
    canvas.scale(k);
    draw(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 幕が開く。半券帳がまだ空のとき
class _Curtain extends _LineArt {
  const _Curtain();

  Path _half(bool left) {
    double x(double v) => left ? v : 120 - v;
    return Path()
      ..moveTo(x(13.1), 22)
      ..lineTo(x(40), 22)
      ..cubicTo(x(42), 36, x(36), 46, x(30), 52)
      ..cubicTo(x(34), 62, x(26), 74, x(22), 82.9)
      ..lineTo(x(13.1), 82.9)
      ..close();
  }

  @override
  void draw(Canvas canvas) {
    final i = ink;
    // 舞台に落ちる明かり（朱の点線）
    final light = Path()
      ..moveTo(60, 24)
      ..lineTo(46, 84)
      ..moveTo(60, 24)
      ..lineTo(74, 84);
    _dashed(canvas, light, Paint()
      ..color = Palette.vermilion
      ..style = PaintingStyle.stroke
      ..strokeWidth = _LineArt.stroke);
    canvas.drawRect(const Rect.fromLTRB(12, 12, 108, 84), i);
    for (final left in [true, false]) {
      double x(double v) => left ? v : 120 - v;
      shuShape(canvas, _half(left));
      // 襞と、幕を寄せて結んだ紐
      canvas.drawPath(
        Path()
          ..moveTo(x(22), 23)
          ..cubicTo(x(24), 36, x(20), 46, x(18), 52)
          ..moveTo(x(31), 23)
          ..cubicTo(x(33), 36, x(28), 46, x(24), 52)
          ..moveTo(x(30), 52)
          ..lineTo(x(13.5), 56),
        i,
      );
    }
    shuShape(canvas, scallop(12, 108, 22, 6, 12));
    canvas.drawLine(const Offset(4, 85), const Offset(116, 85), i);
  }
}

/// 客席。1 つだけ朱の席がある。「みんな」がまだ空のとき
class _Seats extends _LineArt {
  const _Seats();

  @override
  void draw(Canvas canvas) {
    final i = ink;
    shuShape(canvas, scallop(24, 96, 16, 4, 9));
    canvas.drawLine(const Offset(18, 22), const Offset(102, 22), i);
    const rows = [(y: 32.0, n: 5, w: 12.0), (y: 50.0, n: 6, w: 13.5), (y: 70.0, n: 7, w: 14.5)];
    for (final (ri, r) in rows.indexed) {
      const gap = 3.2;
      final total = r.n * r.w + (r.n - 1) * gap;
      final x0 = 60 - total / 2;
      for (var n = 0; n < r.n; n++) {
        final x = x0 + n * (r.w + gap);
        final h = r.w * 0.95;
        final seat = Path()
          ..moveTo(x, r.y + h)
          ..lineTo(x, r.y + 3)
          ..quadraticBezierTo(x, r.y, x + 3, r.y)
          ..lineTo(x + r.w - 3, r.y)
          ..quadraticBezierTo(x + r.w, r.y, x + r.w, r.y + 3)
          ..lineTo(x + r.w, r.y + h)
          ..close();
        if (ri == 1 && n == 3) {
          shuShape(canvas, seat);
        } else {
          canvas.drawPath(seat, i);
        }
      }
    }
  }
}

void _dashed(Canvas canvas, Path path, Paint paint) {
  for (final m in path.computeMetrics()) {
    for (double d = 0; d < m.length; d += 6) {
      canvas.drawPath(m.extractPath(d, d + 3), paint);
    }
  }
}

/// 挿絵を置く。[semantics] は読み上げ用の説明
class LineArt extends StatelessWidget {
  const LineArt._(this._painter, {super.key, required this.width, required this.semantics});

  /// 幕が開く
  const LineArt.curtain({Key? key, double width = 200}) : this._(const _Curtain(), key: key, width: width, semantics: '左右に開いた朱の幕');

  /// 客席
  const LineArt.seats({Key? key, double width = 200}) : this._(const _Seats(), key: key, width: width, semantics: '客席の中に朱の席が 1 つ');

  final CustomPainter _painter;
  final double width;
  final String semantics;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semantics,
    child: SizedBox(width: width, height: width * 100 / 120, child: CustomPaint(painter: _painter)),
  );
}

// ---- 第2弾の挿絵（2026-11-09 にオーナーが OK）。見本ページの描画データをそのまま使う ----

/// 1 つの形。[fill] が無ければ線だけ。[line] が false なら縁取りなし。[rotate] は (角度, 中心 x, 中心 y)
class _Shape {
  const _Shape(this.d, {this.fill, this.line = true, this.w = _LineArt.stroke, this.rotate, this.dashed = false});
  final String d;
  final Color? fill;
  final bool line;
  final double w;
  final (double, double, double)? rotate;
  final bool dashed;
}

String _rect(double x, double y, double w, double h) => 'M$x $y H${x + w} V${y + h} H$x Z';
String _circle(double cx, double cy, double r) => 'M${cx - r} $cy A$r $r 0 1 0 ${cx + r} $cy A$r $r 0 1 0 ${cx - r} $cy Z';
String _ellipse(double cx, double cy, double rx, double ry) => 'M${cx - rx} $cy A$rx $ry 0 1 0 ${cx + rx} $cy A$rx $ry 0 1 0 ${cx - rx} $cy Z';

/// 見本ページで使った SVG のパス（M L H V C Q A Z、絶対座標のみ）を読む
Path _parse(String d) {
  final tokens = RegExp(r'[MLHVCQAZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  final p = Path();
  var i = 0;
  var cur = Offset.zero;
  String? cmd;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[A-Z]$').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        cur = Offset(n(), n());
        p.moveTo(cur.dx, cur.dy);
        cmd = 'L';
      case 'L':
        cur = Offset(n(), n());
        p.lineTo(cur.dx, cur.dy);
      case 'H':
        cur = Offset(n(), cur.dy);
        p.lineTo(cur.dx, cur.dy);
      case 'V':
        cur = Offset(cur.dx, n());
        p.lineTo(cur.dx, cur.dy);
      case 'C':
        final (x1, y1, x2, y2, x, y) = (n(), n(), n(), n(), n(), n());
        p.cubicTo(x1, y1, x2, y2, x, y);
        cur = Offset(x, y);
      case 'Q':
        final (x1, y1, x, y) = (n(), n(), n(), n());
        p.quadraticBezierTo(x1, y1, x, y);
        cur = Offset(x, y);
      case 'A':
        final (rx, ry, _, large, sweep, x, y) = (n(), n(), n(), n(), n(), n(), n());
        cur = Offset(x, y);
        p.arcToPoint(cur, radius: Radius.elliptical(rx, ry), largeArc: large == 1, clockwise: sweep == 1);
      case 'Z':
        p.close();
        cmd = null;
      default:
        i++;
    }
  }
  return p;
}

List<_Shape> _lantern(double cx, double top, double w, double h, bool filled) {
  final out = <_Shape>[
    _Shape('M$cx ${top - 4} V$top'),
    _Shape(_rect(cx - w * 0.32, top, w * 0.64, 4), fill: Palette.paper),
    _Shape(_ellipse(cx, top + 4 + h / 2, w / 2, h / 2), fill: filled ? Palette.vermilion : Palette.paper),
  ];
  for (final k in [-0.5, 0.0, 0.5]) {
    final y = top + 4 + h / 2 + k * h * 0.6;
    final half = (w / 2) * math.sqrt(1 - math.pow(k * 0.6 * 2, 2));
    out.add(_Shape('M${cx - half} $y Q$cx ${y + 2} ${cx + half} $y'));
  }
  out.add(_Shape(_rect(cx - w * 0.32, top + 4 + h, w * 0.64, 4), fill: Palette.paper));
  return out;
}

class _ShapesArt extends _LineArt {
  const _ShapesArt(this.shapes);
  final List<_Shape> shapes;

  @override
  void draw(Canvas canvas) {
    for (final s in shapes) {
      final path = _parse(s.d);
      canvas.save();
      if (s.rotate case (final deg, final x, final y)) {
        canvas
          ..translate(x, y)
          ..rotate(deg * math.pi / 180)
          ..translate(-x, -y);
      }
      if (s.fill != null) canvas.drawPath(path, Paint()..color = s.fill!);
      if (s.line) {
        final p = ink..strokeWidth = s.w;
        s.dashed ? _dashed(canvas, path, p) : canvas.drawPath(path, p);
      }
      canvas.restore();
    }
  }
}

const _sumi = Palette.sumi, _shu = Palette.vermilion, _paper = Palette.paper, _kin = Palette.kincha, _kinari = Palette.kinari;

final _light = [
  const _Shape('M47 41 L56 51 L54 90 L8 90 Z', fill: _kinari, line: false),
  _Shape(_ellipse(31, 90, 23, 4), fill: _kin, line: false),
  _Shape(_rect(6, 9, 108, 5), fill: _sumi),
  const _Shape('M66 14 V22'),
  const _Shape('M58 22 H74 V30 H72 V24 H60 V30 H58 Z', fill: _paper),
  _Shape(_rect(52, 26, 30, 18), fill: _sumi, rotate: (-30, 66, 35)),
  _Shape(_rect(46, 23, 7, 24), fill: _kin, rotate: (-30, 66, 35)),
  const _Shape('M82 30 H88 V40 H82', rotate: (-30, 66, 35)),
  const _Shape('M86 44 C96 56 104 50 108 62'),
  const _Shape('M2 94 H118'),
];

final _flashlight = [
  const _Shape('M84 46 L88 58 L44 86 L20 70 Z', fill: _kinari, line: false),
  _Shape(_circle(40, 76, 9), w: 1.6, dashed: true),
  _Shape(_rect(86, 40, 26, 11), fill: _sumi, rotate: (-28, 86, 46)),
  _Shape(_rect(80, 38, 8, 15), fill: _kin, rotate: (-28, 86, 46)),
  _Shape(_rect(98, 38, 5, 3), fill: _shu, rotate: (-28, 86, 46)),
  const _Shape('M2 92 H118'),
];

final _reception = [
  _Shape(_rect(10, 52, 100, 36), fill: _shu),
  const _Shape('M10 58 H110', w: 1.3),
  _Shape(_rect(10, 46, 100, 6), fill: _kinari),
  _Shape(_rect(22, 18, 34, 30), fill: _paper, rotate: (-6, 39, 33)),
  const _Shape('M27 25 H51 M27 31 H51 M27 37 H47', w: 1.3, rotate: (-6, 39, 33)),
  _Shape(_rect(26, 35, 4, 4), fill: _shu, line: false, rotate: (-6, 39, 33)),
  _Shape(_rect(66, 30, 26, 16), fill: _kinari, rotate: (4, 79, 38)),
  _Shape(_rect(70, 26, 26, 16), fill: _kinari, rotate: (-3, 83, 34)),
  const _Shape('M70 26 L83 35 L96 26', w: 1.3, rotate: (-3, 83, 34)),
  _Shape(_rect(56, 40, 22, 3), fill: _sumi, rotate: (-20, 67, 41)),
  const _Shape('M14 88 V96 M106 88 V96'),
];

final _unplugged = [
  _Shape(_rect(6, 9, 108, 5), fill: _sumi),
  const _Shape('M46 14 V22'),
  const _Shape('M38 22 H54 V30 H52 V24 H40 V30 H38 Z', fill: _paper),
  _Shape(_rect(32, 26, 30, 18), fill: _sumi, rotate: (-30, 46, 35)),
  _Shape(_rect(26, 23, 7, 24), fill: _paper, rotate: (-30, 46, 35)),
  const _Shape('M62 40 C76 52 70 66 78 74 C82 78 86 78 88 76'),
  _Shape(_rect(86, 71, 10, 8), fill: _sumi),
  _Shape(_rect(96, 73, 4, 1.6), fill: _kin, line: false),
  _Shape(_rect(96, 76.4, 4, 1.6), fill: _kin, line: false),
  _Shape(_rect(102, 70, 14, 22), fill: _shu),
  _Shape(_rect(105, 76, 2, 5), fill: _sumi, line: false),
  _Shape(_rect(110, 76, 2, 5), fill: _sumi, line: false),
  const _Shape('M99 64 L96 60 M103 63 V58 M95 68 L91 66', w: 1.6),
  const _Shape('M2 92 H118'),
];

final _album = [
  const _Shape('M8 20 H58 L60 22 L62 20 H112 V84 H62 L60 86 L58 84 H8 Z', fill: _kinari),
  const _Shape('M60 22 V86'),
  _Shape(_rect(16, 28, 34, 26), fill: _paper, rotate: (-5, 33, 41)),
  _Shape(_rect(19, 31, 28, 17), fill: _sumi, line: false, rotate: (-5, 33, 41)),
  const _Shape('M24 48 V40 Q33 32 42 40 V48 Z', fill: _paper, line: false, rotate: (-5, 33, 41)),
  _Shape(_rect(12, 24, 12, 5), fill: _kin, line: false, rotate: (-35, 18, 26)),
  _Shape(_rect(20, 58, 30, 22), fill: _paper, rotate: (4, 35, 69)),
  _Shape(_rect(23, 61, 24, 13), fill: _sumi, line: false, rotate: (4, 35, 69)),
  _Shape(_circle(35, 64, 3), fill: _paper, line: false, rotate: (4, 35, 69)),
  const _Shape('M27 74 L35 67 L43 74 Z', fill: _paper, line: false, rotate: (4, 35, 69)),
  _Shape(_rect(42, 76, 12, 5), fill: _kin, line: false, rotate: (35, 48, 78)),
  _Shape(_rect(68, 30, 38, 15), fill: _paper, rotate: (-6, 87, 37)),
  const _Shape('M78 31 V44', w: 1.2, rotate: (-6, 87, 37)),
  const _Shape('M84 35 H100 M84 40 H95', w: 1.2, rotate: (-6, 87, 37)),
  _Shape(_circle(73, 37, 3.5), fill: _shu, line: false, rotate: (-6, 87, 37)),
  _Shape(_rect(98, 26, 12, 5), fill: _kin, line: false, rotate: (30, 104, 28)),
  _Shape(_rect(70, 52, 30, 26), fill: _paper, rotate: (5, 85, 65)),
  _Shape(_rect(74, 56, 22, 4), fill: _sumi, line: false, rotate: (5, 85, 65)),
  const _Shape('M74 65 H94 M74 70 H88', w: 1.3, rotate: (5, 85, 65)),
  _Shape(_rect(92, 74, 12, 5), fill: _kin, line: false, rotate: (-30, 98, 76)),
];

final _passport = [
  const _Shape('M6 20 H114 V86 H6 Z', fill: _sumi),
  const _Shape('M10 22 H58 L60 24 L62 22 H110 V82 H62 L60 84 L58 82 H10 Z', fill: _paper),
  const _Shape('M60 24 V84'),
  _Shape(_circle(30, 42, 11), w: 1.8),
  _Shape(_circle(30, 42, 8), w: 1),
  const _Shape('M24 42 H36 M26 46 H34', w: 1.2),
  _Shape(_rect(18, 60, 26, 16), w: 1.8, rotate: (6, 31, 68)),
  const _Shape('M22 66 H40 M22 70 H34', w: 1.2, rotate: (6, 31, 68)),
  _Shape(_circle(86, 52, 18), fill: _shu, line: false),
  _Shape(_circle(86, 52, 14.5), fill: _paper, line: false),
  const _Shape('M76 62 V50 Q86 38 96 50 V62 Z', fill: _shu, line: false),
  const _Shape('M79.5 62 V51 Q86 43 92.5 51 V62 Z', fill: _paper, line: false),
  _Shape(_rect(75, 62, 22, 2.6), fill: _shu, line: false),
];

final _lanterns = [
  const _Shape('M4 22 Q60 40 116 22'),
  ..._lantern(22, 30, 16, 22, true),
  ..._lantern(46, 35, 16, 22, false),
  ..._lantern(74, 35, 16, 22, true),
  ..._lantern(98, 30, 16, 22, false),
];

final _survey = [
  _Shape(_rect(28, 12, 56, 78), fill: _kin),
  _Shape(_rect(33, 20, 46, 64), fill: _paper),
  _Shape(_rect(46, 8, 20, 9), fill: _sumi),
  const _Shape('M39 30 H72 M39 36 H64', w: 1.3),
  _Shape(_rect(39, 44, 6, 6), w: 1.3),
  const _Shape('M49 47 H72', w: 1.3),
  _Shape(_rect(39, 56, 6, 6), fill: _shu, w: 1.3),
  const _Shape('M49 59 H70', w: 1.3),
  _Shape(_rect(39, 68, 6, 6), w: 1.3),
  const _Shape('M49 71 H66', w: 1.3),
  _Shape(_rect(74, 56, 40, 7), fill: _kin, rotate: (-38, 94, 60)),
  const _Shape('M74 56 L66 59.5 L74 63 Z', fill: _kinari, rotate: (-38, 94, 60)),
  _Shape(_rect(110, 56, 5, 7), fill: _shu, rotate: (-38, 94, 60)),
];

/// 第2弾の挿絵を置く
class StageArt extends StatelessWidget {
  const StageArt._(this._shapes, this._label, {super.key, required this.width});

  /// 舞台照明。ふりかえり
  StageArt.light({Key? key, double width = 180}) : this._(_light, '吊られた照明が床を照らしている', key: key, width: width);

  /// 案内係の懐中電灯。探して見つからなかったとき
  StageArt.flashlight({Key? key, double width = 160}) : this._(_flashlight, '懐中電灯が照らした先に何もない', key: key, width: width);

  /// 受付のテーブル。ログイン
  StageArt.reception({Key? key, double width = 180}) : this._(_reception, '受付のテーブルに予約の名簿とチケット', key: key, width: width);

  /// 抜けたケーブル。通信できないとき
  StageArt.unplugged({Key? key, double width = 160}) : this._(_unplugged, '照明のケーブルが抜けている', key: key, width: width);

  /// 観劇のアルバム。写真を残す
  StageArt.album({Key? key, double width = 72}) : this._(_album, '写真と半券を貼ったアルバム', key: key, width: width);

  /// 劇場パスポート。劇場スタンプ
  StageArt.passport({Key? key, double width = 72}) : this._(_passport, '劇場の印が並ぶ手帳', key: key, width: width);

  /// 提灯の列。スタンプ帳の上
  StageArt.lanterns({Key? key, double width = 220}) : this._(_lanterns, '縄に下がった提灯の列', key: key, width: width);

  /// アンケート用紙。感想を公開する前
  StageArt.survey({Key? key, double width = 110}) : this._(_survey, 'バインダーに挟んだアンケート用紙と鉛筆', key: key, width: width);

  final List<_Shape> _shapes;
  final String _label;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: _label,
    child: SizedBox(width: width, height: width * 100 / 120, child: CustomPaint(painter: _ShapesArt(_shapes))),
  );
}
