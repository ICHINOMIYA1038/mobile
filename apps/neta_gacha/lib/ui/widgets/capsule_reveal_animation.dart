import 'dart:math' as math;

import 'package:flutter/material.dart';

/// カプセルが揺れて→パカッと割れて→中の紙が出てくる、抽選結果の演出。
///
/// [key]を変えるたびに(RouletteScreen側で抽選のたびに新しいキーを渡す)Stateが
/// 作り直され、初期化のタイミングでアニメーションが最初から再生される。
class CapsuleRevealAnimation extends StatefulWidget {
  const CapsuleRevealAnimation({
    super.key,
    required this.capsuleColor,
    required this.child,
  });

  final Color capsuleColor;
  final Widget child;

  @override
  State<CapsuleRevealAnimation> createState() =>
      _CapsuleRevealAnimationState();
}

class _CapsuleRevealAnimationState extends State<CapsuleRevealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // フェーズ1: 揺れる(0.00-0.30)
        final shakeT = (t / 0.30).clamp(0.0, 1.0);
        final shakeEnvelope = (1 - shakeT);
        final shakeAngle = math.sin(shakeT * 4 * math.pi) * 0.12 * shakeEnvelope;
        final shakeScale = 1.0 + 0.08 * math.sin(shakeT * math.pi);

        // フェーズ2: 割れる(0.28-0.55)
        final splitT = ((t - 0.28) / 0.27).clamp(0.0, 1.0);

        // フェーズ3: 中身が出てくる(0.45-1.00)
        final revealT = Curves.easeOutBack.transform(
          ((t - 0.45) / 0.55).clamp(0.0, 1.0),
        );
        final revealOpacity = ((t - 0.45) / 0.25).clamp(0.0, 1.0);

        final capsuleOpacity = 1 - splitT;

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: revealOpacity,
              child: Transform.scale(
                scale: 0.75 + 0.25 * revealT,
                child: child,
              ),
            ),
            if (capsuleOpacity > 0)
              Transform.rotate(
                angle: shakeAngle,
                child: Transform.scale(
                  scale: shakeScale,
                  child: Opacity(
                    opacity: capsuleOpacity,
                    child: _CapsuleHalves(
                      color: widget.capsuleColor,
                      splitT: splitT,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _CapsuleHalves extends StatelessWidget {
  const _CapsuleHalves({required this.color, required this.splitT});

  final Color color;
  final double splitT;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-splitT * 26, -splitT * 18),
            child: Transform.rotate(
              angle: -splitT * 0.5,
              child: ClipPath(
                clipper: _HalfCircleClipper(top: true),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(splitT * 26, splitT * 18),
            child: Transform.rotate(
              angle: splitT * 0.5,
              child: ClipPath(
                clipper: _HalfCircleClipper(top: false),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfCircleClipper extends CustomClipper<Path> {
  const _HalfCircleClipper({required this.top});

  final bool top;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (top) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height / 2));
    } else {
      path.addRect(
        Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _HalfCircleClipper oldClipper) =>
      oldClipper.top != top;
}
