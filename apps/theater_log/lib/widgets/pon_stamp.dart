import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pon_sound.dart';
import '../theme.dart';

/// 朱肉で紙に押したハンコの跡。塗りつぶしではなく、輪と文字を朱で押す（朱文）。
/// [bottom] があると日付印の形になる：上に [label]、中の帯に [sub]、下に [bottom]
class PonSeal extends StatelessWidget {
  const PonSeal({super.key, required this.size, required this.label, this.sub, this.bottom, this.fontSize, this.color = Palette.vermilion, this.square = false});
  final double size;

  /// 角印にする（丸印と押し分けて、集めたときに見た目に変化を付ける）
  final bool square;
  final String label;
  final String? sub;
  final String? bottom;
  final double? fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: [label.replaceAll('\n', ''), ?sub, ?bottom].join(' '),
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SealPainter(label: label, sub: sub, bottom: bottom, fontSize: fontSize, color: color, square: square),
        ),
      ),
    ),
  );
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.label, this.sub, this.bottom, this.fontSize, required this.color, this.square = false});
  final bool square;
  final String label;
  final String? sub;
  final String? bottom;
  final double? fontSize;
  final Color color;

  TextPainter _text(String text, double size, {String? family, FontWeight weight = FontWeight.w800, double height = 1.1, double spacing = 0}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontSize: size, height: height, fontWeight: weight, color: color, letterSpacing: spacing),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();

  /// 幅 [maxW]・高さ [maxH] に収まるよう縮めて、中心 [c] に置く
  void _fit(Canvas canvas, TextPainter tp, Offset c, double maxW, double maxH) {
    final k = math.min(1.0, math.min(maxW / tp.width, maxH / tp.height));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final seed = label.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final rnd = math.Random(seed);
    canvas.saveLayer(Offset.zero & size, Paint());

    // 外の輪は太く、押しむらで少し揺らす
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.085);
    final inner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.025);
    final innerR = r * 0.80;
    if (square) {
      // 角印：太い外枠と細い内枠。角は少しだけ丸める
      final o = ring.strokeWidth / 2 + 0.5;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(o, o, size.width - o, size.height - o), Radius.circular(r * 0.08)), ring);
      final i = r - innerR;
      canvas.drawRect(Rect.fromLTRB(i, i, size.width - i, size.height - i), inner);
    } else {
      final outer = Path();
      const steps = 72;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps * math.pi * 2;
        final wobble = 1 + (math.sin(t * 3 + seed % 7) * 0.006) + (math.sin(t * 7 + seed % 5) * 0.004);
        final p = c + Offset(math.cos(t), math.sin(t)) * (r - ring.strokeWidth / 2 - 0.5) * wobble;
        i == 0 ? outer.moveTo(p.dx, p.dy) : outer.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(outer..close(), ring);
      canvas.drawCircle(c, innerR, inner);
    }

    final base = fontSize ?? size.width * 0.2;
    if (bottom != null) {
      // 日付印：上・帯・下の三段
      final band = innerR * 0.36;
      final rule = Paint()
        ..color = color
        ..strokeWidth = math.max(0.6, r * 0.03);
      final half = math.sqrt(innerR * innerR - band * band);
      canvas.drawLine(c + Offset(-half, -band), c + Offset(half, -band), rule);
      canvas.drawLine(c + Offset(-half, band), c + Offset(half, band), rule);
      _fit(canvas, _text(label, base, family: sealFont), c + Offset(0, -band - (innerR - band) * 0.48), innerR * 1.25, (innerR - band) * 0.8);
      if (sub != null) _fit(canvas, _text(sub!, base * 0.95, family: displayFont, weight: FontWeight.w400, spacing: 0.5), c, half * 1.8, band * 1.5);
      _fit(canvas, _text(bottom!, base * 0.8, family: sealFont), c + Offset(0, band + (innerR - band) * 0.48), innerR * 1.25, (innerR - band) * 0.8);
    } else {
      final main = _text(label, base, family: sealFont, height: 1.12);
      if (sub == null) {
        _fit(canvas, main, c, innerR * 1.5, innerR * 1.5);
      } else {
        final small = _text(sub!, base * 0.6, weight: FontWeight.w700);
        final total = main.height + small.height + innerR * 0.06;
        final k = math.min(1.0, math.min(innerR * 1.5 / math.max(main.width, small.width), innerR * 1.5 / total));
        final top = c.dy - total * k / 2;
        _fit(canvas, main, Offset(c.dx, top + main.height * k / 2), innerR * 1.5, main.height * k);
        _fit(canvas, small, Offset(c.dx, top + (main.height + innerR * 0.06 + small.height / 2) * k), innerR * 1.5, small.height * k);
      }
    }

    // 朱肉のかすれ。紙の白が抜けたところを小さく散らす
    final knock = Paint()..blendMode = BlendMode.dstOut;
    final specks = (size.width * size.width / 55).round().clamp(18, 420);
    for (var i = 0; i < specks; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = math.sqrt(rnd.nextDouble()) * r;
      final pr = (0.25 + rnd.nextDouble() * 0.9) * math.max(0.5, size.width / 120);
      knock.color = Colors.black.withValues(alpha: 0.35 + rnd.nextDouble() * 0.55);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, pr, knock);
    }
    // 片側が少し薄い（押す力のむら）
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = LinearGradient(
          begin: Alignment(-0.9 + (seed % 5) * 0.1, -1),
          end: const Alignment(0.8, 1),
          colors: [Colors.black.withValues(alpha: 0.18), Colors.transparent, Colors.black.withValues(alpha: 0.06)],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.label != label || old.sub != sub || old.bottom != bottom || old.fontSize != fontSize || old.color != color || old.square != square;
}

/// ハンコが落ちてきてポンと押される動き。押した瞬間に音と振動を出す
class PonStamp extends StatefulWidget {
  const PonStamp({super.key, required this.child, this.delay = Duration.zero, this.onImpact});
  final Widget child;
  final Duration delay;
  final VoidCallback? onImpact;

  static const drop = Duration(milliseconds: 200);
  static const after = Duration(milliseconds: 1000);

  @override
  State<PonStamp> createState() => _PonStampState();
}

class _PonStampState extends State<PonStamp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final double _impactAt;
  bool _impacted = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + PonStamp.drop + PonStamp.after;
    _impactAt = (widget.delay + PonStamp.drop).inMicroseconds / total.inMicroseconds;
    _c = AnimationController(vsync: this, duration: total)
      ..addListener(() {
        if (_c.value >= _impactAt) _impact();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 動きを減らす設定の人には、押された状態を最初から見せる
    _c.value = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  void _impact() {
    if (_impacted) return;
    _impacted = true;
    HapticFeedback.heavyImpact();
    PonSound.play();
    widget.onImpact?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 押した瞬間を 0 として、[ms] ミリ秒かけて 0 から 1 へ進む
  double _since(int ms, {int from = 0}) {
    final total = _c.duration!.inMilliseconds;
    final elapsed = (_c.value - _impactAt) * total - from;
    return (elapsed / ms).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final falling = _impactAt == 0 ? 1.0 : (_c.value / _impactAt).clamp(0.0, 1.0);
          final dropStart = widget.delay.inMicroseconds / (widget.delay + PonStamp.drop).inMicroseconds;
          final fall = Curves.easeIn.transform(((falling - dropStart) / (1 - dropStart)).clamp(0.0, 1.0));
          // 押し込んで、少し弾んで戻る
          final press = math.sin(_since(170) * math.pi) * (1 - _since(170)) * 0.3;
          final scale = _c.value < _impactAt ? 3.0 - 2.0 * fall : 1 - press;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (!reduced && _impacted && _since(420) < 1) Positioned.fill(child: CustomPaint(painter: _InkBurst(_since(420)))),
              Opacity(
                opacity: fall < 0.02 ? 0 : math.min(1, fall * 3),
                child: Transform.rotate(
                  angle: -0.2 + 0.14 * (1 - fall),
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 押した勢いで少しだけ飛ぶ朱肉
class _InkBurst extends CustomPainter {
  const _InkBurst(this.t);
  final double t;

  static const _drops = [
    (0.1, 1.0, 5.0),
    (0.75, 1.3, 3.5),
    (1.4, 0.95, 4.5),
    (2.1, 1.25, 3.0),
    (2.7, 1.05, 5.5),
    (3.4, 1.35, 3.5),
    (4.0, 0.95, 4.0),
    (4.6, 1.3, 3.0),
    (5.2, 1.1, 5.0),
    (5.8, 1.25, 3.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final eased = Curves.easeOut.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    final drop = Paint()..color = Palette.vermilion.withValues(alpha: fade);
    for (final (angle, reach, r) in _drops) {
      final d = radius * (0.98 + (reach - 0.9) * eased * 0.5);
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * d, r * 0.45 * (1 - 0.5 * t), drop);
    }
  }

  @override
  bool shouldRepaint(_InkBurst old) => old.t != t;
}
