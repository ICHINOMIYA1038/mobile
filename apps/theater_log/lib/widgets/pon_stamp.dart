import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pon_sound.dart';
import '../theme.dart';

/// 朱肉の丸いハンコ
class PonSeal extends StatelessWidget {
  const PonSeal({super.key, required this.size, required this.label, this.sub, this.fontSize});
  final double size;
  final String label;
  final String? sub;
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.06),
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.vermilion),
    child: Container(
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.paper, width: math.max(1, size * 0.018))),
      // 長い名前でも切らずに、丸の内側に収まるまで縮める
      child: SizedBox(
        width: size * 0.66,
        height: size * 0.62,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                softWrap: false,
                style: TextStyle(fontFamily: sealFont, fontSize: fontSize ?? size * 0.2, height: 1.15, fontWeight: FontWeight.w800, color: Palette.paper),
              ),
              if (sub != null) Text(sub!, softWrap: false, style: TextStyle(fontSize: (fontSize ?? size * 0.2) * 0.62, height: 1.3, fontWeight: FontWeight.w700, color: Palette.paper)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// ハンコが落ちてきて「ポン！」と押される動き。押した瞬間に音と振動を出す
class PonStamp extends StatefulWidget {
  const PonStamp({super.key, required this.child, this.delay = Duration.zero, this.onImpact, this.wordAt = const Offset(-46, -44)});
  final Widget child;
  final Duration delay;
  final VoidCallback? onImpact;

  /// 「ポン！」を出す位置（ハンコの左上から）。周りの文字に重ならない場所を選ぶ
  final Offset wordAt;

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
          final word = _since(320);
          final wordOut = _since(250, from: 700);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (!reduced && _impacted && _since(420) < 1)
                Positioned.fill(child: CustomPaint(painter: _InkBurst(_since(420)))),
              Opacity(
                opacity: fall < 0.02 ? 0 : math.min(1, fall * 3),
                child: Transform.rotate(angle: -0.2 + 0.14 * (1 - fall), child: Transform.scale(scale: scale, child: child)),
              ),
              if (!reduced && _impacted && wordOut < 1)
                Positioned(
                  top: widget.wordAt.dy - 18 * word,
                  left: widget.wordAt.dx,
                  child: Opacity(
                    opacity: 1 - wordOut,
                    child: Transform.rotate(
                      angle: -0.16,
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform(word),
                        child: const Text(
                          'ポン！',
                          key: Key('pon-word'),
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFFFFD166), shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 押した勢いで飛ぶ朱肉
class _InkBurst extends CustomPainter {
  const _InkBurst(this.t);
  final double t;

  static const _drops = [
    (0.1, 1.0, 5.0), (0.75, 1.3, 3.5), (1.4, 0.95, 4.5), (2.1, 1.25, 3.0), (2.7, 1.05, 5.5), (3.4, 1.35, 3.5),
    (4.0, 0.95, 4.0), (4.6, 1.3, 3.0), (5.2, 1.1, 5.0), (5.8, 1.25, 3.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final eased = Curves.easeOut.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius * (1 + 0.55 * eased),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * fade
        ..color = const Color(0xFFFFD166).withValues(alpha: 0.8 * fade),
    );
    final drop = Paint()..color = Palette.vermilion.withValues(alpha: fade);
    for (final (angle, reach, r) in _drops) {
      final d = radius * (1 + (reach - 0.55) * eased * 1.1);
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * d, r * (1 - 0.4 * t), drop);
    }
  }

  @override
  bool shouldRepaint(_InkBurst old) => old.t != t;
}
