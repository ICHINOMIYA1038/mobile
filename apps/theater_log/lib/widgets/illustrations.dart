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
