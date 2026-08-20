import 'dart:math' as math;

import 'package:flutter/material.dart';

/// アナログ騒音計を模した円形ゲージ。目盛り・トラック・レベル弧・針を描く。
/// [level] は0.0(無音)〜1.0(最大)に正規化した現在値。
class LevelGauge extends StatelessWidget {
  const LevelGauge({super.key, required this.level, this.size = 200});

  final double level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LevelGaugePainter(
          level: level.clamp(0.0, 1.0),
          brightness: Theme.of(context).brightness,
        ),
      ),
    );
  }
}

class _LevelGaugePainter extends CustomPainter {
  _LevelGaugePainter({required this.level, required this.brightness});

  final double level;
  final Brightness brightness;

  static const _startDeg = -210.0;
  static const _sweepDeg = 240.0;
  static const _tickCount = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.42;
    final side = size.shortestSide;

    final trackColor = isDark
        ? const Color(0x24ECE8DE)
        : const Color(0x1F2B2820);
    final accent = isDark ? const Color(0xFFE3A85B) : const Color(0xFFB9792E);
    final tickMinor = (isDark
            ? const Color(0xFF9E9887)
            : const Color(0xFF7A7565))
        .withValues(alpha: 0.55);
    final tickMajor = (isDark
            ? const Color(0xFFECE8DE)
            : const Color(0xFF2B2820))
        .withValues(alpha: 0.85);
    final hubFill = isDark
        ? const Color(0xFF17191E)
        : const Color(0xFFEFEAE0);

    final minorPaint = Paint()
      ..color = tickMinor
      ..strokeWidth = side * 0.009
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = tickMajor
      ..strokeWidth = side * 0.011
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _tickCount; i++) {
      final deg = _startDeg + _sweepDeg * i / (_tickCount - 1);
      final rad = deg * math.pi / 180;
      final dir = Offset(math.cos(rad), math.sin(rad));
      final major = i % 4 == 0;
      final rInner = r * (major ? 0.83 : 0.89);
      canvas.drawLine(
        center + dir * rInner,
        center + dir * r,
        major ? majorPaint : minorPaint,
      );
    }

    final arcRect = Rect.fromCircle(center: center, radius: r * 0.78);
    final strokeW = side * 0.045;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      _startDeg * math.pi / 180,
      _sweepDeg * math.pi / 180,
      false,
      trackPaint,
    );

    if (level > 0) {
      final levelPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        arcRect,
        _startDeg * math.pi / 180,
        _sweepDeg * math.pi / 180 * level,
        false,
        levelPaint,
      );
    }

    final needleDeg = _startDeg + _sweepDeg * level;
    final needleRad = needleDeg * math.pi / 180;
    final needleEnd =
        center +
        Offset(math.cos(needleRad), math.sin(needleRad)) * (r * 0.78);
    final needlePaint = Paint()
      ..color = accent
      ..strokeWidth = side * 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    canvas.drawCircle(center, side * 0.032, Paint()..color = hubFill);
    canvas.drawCircle(
      center,
      side * 0.032,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.014,
    );
  }

  @override
  bool shouldRepaint(covariant _LevelGaugePainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.brightness != brightness;
  }
}
