import 'package:flutter/material.dart';

import '../theme.dart';

/// ホーム画面のヒーローに置く、ガチャガチャ本体のイラスト。
/// 外部画像を使わず、すべてCanvasの図形で描く(手描きの一枚絵のような一点物にしないため、
/// 実機での再現性と軽量さを優先した)。
class CapsuleMachineIllustration extends StatelessWidget {
  const CapsuleMachineIllustration({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: height,
      width: height,
      child: CustomPaint(
        painter: _CapsuleMachinePainter(glassTint: colors.machineGlass),
      ),
    );
  }
}

// ドーム内に並べるカプセルの相対配置(ドーム中心を原点、半径を1とした座標系)。
// dx, dy: 中心からのオフセット比率 / r: 半径比率 / colorIndex: kCapsuleColorsの添字。
const _capsuleLayout = [
  (dx: -0.42, dy: 0.30, r: 0.24, colorIndex: 0),
  (dx: 0.10, dy: 0.42, r: 0.20, colorIndex: 1),
  (dx: 0.48, dy: 0.18, r: 0.22, colorIndex: 2),
  (dx: -0.10, dy: 0.02, r: 0.26, colorIndex: 3),
  (dx: -0.46, dy: -0.28, r: 0.19, colorIndex: 4),
  (dx: 0.34, dy: -0.20, r: 0.21, colorIndex: 5),
  (dx: 0.02, dy: -0.44, r: 0.18, colorIndex: 6),
  (dx: -0.62, dy: 0.02, r: 0.16, colorIndex: 2),
];

class _CapsuleMachinePainter extends CustomPainter {
  const _CapsuleMachinePainter({required this.glassTint});

  final Color glassTint;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final domeCenter = Offset(cx, s * 0.36);
    final domeRadius = s * 0.33;

    _paintBase(canvas, size, cx, domeCenter, domeRadius);
    _paintCapsules(canvas, domeCenter, domeRadius);
    _paintDomeGlass(canvas, domeCenter, domeRadius);
    _paintKnobAndDetails(canvas, size, cx, domeCenter, domeRadius);
  }

  void _paintBase(
    Canvas canvas,
    Size size,
    double cx,
    Offset domeCenter,
    double domeRadius,
  ) {
    final baseTop = domeCenter.dy + domeRadius * 0.62;
    final baseWidth = domeRadius * 1.9;
    final baseHeight = size.height - baseTop - size.height * 0.02;
    final baseRect = Rect.fromLTWH(
      cx - baseWidth / 2,
      baseTop,
      baseWidth,
      baseHeight,
    );
    final baseRRect = RRect.fromRectAndCorners(
      baseRect,
      topLeft: Radius.circular(baseWidth * 0.18),
      topRight: Radius.circular(baseWidth * 0.18),
      bottomLeft: Radius.circular(baseWidth * 0.08),
      bottomRight: Radius.circular(baseWidth * 0.08),
    );

    canvas.drawRRect(
      baseRRect,
      Paint()..color = gachaOrange,
    );
    // 影の帯で立体感を出す。
    canvas.drawRRect(
      baseRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent],
        ).createShader(baseRect),
    );

    // 取り出し口。
    final flapWidth = baseWidth * 0.42;
    final flapRect = Rect.fromLTWH(
      cx - flapWidth / 2,
      baseRect.bottom - baseHeight * 0.32,
      flapWidth,
      baseHeight * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(flapRect, Radius.circular(flapWidth * 0.16)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // コイン投入口。
    final coinSlot = Rect.fromCenter(
      center: Offset(cx, baseRect.top + baseHeight * 0.22),
      width: baseWidth * 0.22,
      height: baseHeight * 0.06,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(coinSlot, Radius.circular(coinSlot.height / 2)),
      Paint()..color = inkNavy.withValues(alpha: 0.35),
    );
  }

  void _paintCapsules(Canvas canvas, Offset domeCenter, double domeRadius) {
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: domeCenter, radius: domeRadius)),
    );
    for (final c in _capsuleLayout) {
      final center = Offset(
        domeCenter.dx + c.dx * domeRadius,
        domeCenter.dy + c.dy * domeRadius,
      );
      final r = c.r * domeRadius;
      final color = kCapsuleColors[c.colorIndex % kCapsuleColors.length];
      _paintCapsule(canvas, center, r, color);
    }
    canvas.restore();
  }

  void _paintCapsule(Canvas canvas, Offset center, double r, Color color) {
    // 下半分: 濃いめの色。上半分: 白っぽいフタ。実物のカプセルトイの二色構成。
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    final bottomPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: r), 0, 3.14159);
    canvas.drawPath(bottomPath, Paint()..color = color);
    // 中央の合わせ目ライン。
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..strokeWidth = r * 0.08,
    );
    // ハイライト。
    canvas.drawCircle(
      Offset(center.dx - r * 0.35, center.dy - r * 0.45),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _paintDomeGlass(Canvas canvas, Offset domeCenter, double domeRadius) {
    final domeRect = Rect.fromCircle(center: domeCenter, radius: domeRadius);
    canvas.drawOval(
      domeRect,
      Paint()
        ..color = glassTint
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      domeRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = domeRadius * 0.045,
    );
    // ガラスの反射ハイライト。
    final highlight = Path()
      ..addArc(
        Rect.fromCircle(
          center: domeCenter.translate(-domeRadius * 0.28, -domeRadius * 0.3),
          radius: domeRadius * 0.38,
        ),
        3.6,
        1.6,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = domeRadius * 0.12
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintKnobAndDetails(
    Canvas canvas,
    Size size,
    double cx,
    Offset domeCenter,
    double domeRadius,
  ) {
    final baseTop = domeCenter.dy + domeRadius * 0.62;
    final baseWidth = domeRadius * 1.9;
    final knobCenter = Offset(
      cx + baseWidth / 2 + baseWidth * 0.06,
      baseTop + (size.height - baseTop) * 0.42,
    );
    final knobRadius = baseWidth * 0.14;
    canvas.drawCircle(knobCenter, knobRadius, Paint()..color = liveViolet);
    canvas.drawCircle(
      knobCenter,
      knobRadius * 0.4,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _CapsuleMachinePainter oldDelegate) {
    return oldDelegate.glassTint != glassTint;
  }
}
