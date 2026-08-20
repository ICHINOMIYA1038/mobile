import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 「ガチャを引く」操作を、ノブをひねるような手触りで表現するボタン。
/// タップするとノブが1回転してから[onPressed]を呼ぶ。
class GachaKnobButton extends StatefulWidget {
  const GachaKnobButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<GachaKnobButton> createState() => _GachaKnobButtonState();
}

class _GachaKnobButtonState extends State<GachaKnobButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_controller.isAnimating) return;
    await _controller.forward(from: 0);
    _controller.reset();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _turn,
            builder: (context, child) {
              return Transform.rotate(
                angle: _turn.value * 2 * math.pi,
                child: child,
              );
            },
            child: const _KnobDial(),
          ),
          const SizedBox(height: 12),
          Text(
            'ガチャを引く',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _KnobDial extends StatelessWidget {
  const _KnobDial();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(painter: _KnobPainter()),
    );
  }
}

class _KnobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black,
      6,
      false,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [liveViolet.withValues(alpha: 0.95), liveViolet],
          center: const Alignment(-0.3, -0.35),
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 縁のグリップ(滑り止めの刻み)。
    final gripPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = radius * 0.06
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * math.pi;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.94;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.82;
      canvas.drawLine(inner, outer, gripPaint);
    }

    canvas.drawCircle(
      center,
      radius * 0.6,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    final icon = Icons.casino_rounded;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: radius * 0.75,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) => false;
}
