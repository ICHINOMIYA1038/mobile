import 'package:flutter/material.dart';

/// ページ全体にうっすら敷く、紙にスタンプで押したようなドット柄の背景。
class DotPatternBackground extends StatelessWidget {
  const DotPatternBackground({
    super.key,
    required this.child,
    required this.dotColor,
    this.spacing = 28,
    this.radius = 1.6,
  });

  final Widget child;
  final Color dotColor;
  final double spacing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DotPatternPainter(
              color: dotColor,
              spacing: spacing,
              radius: radius,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      // 1行おきに半マスずらして、印刷物のドット柄っぽい規則性を崩す。
      final rowIndex = (y / spacing).round();
      final offsetX = rowIndex.isOdd ? spacing / 2 : 0.0;
      for (double x = spacing / 2 + offsetX; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
