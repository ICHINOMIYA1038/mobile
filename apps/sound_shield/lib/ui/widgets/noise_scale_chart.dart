import 'package:flutter/material.dart';

import '../../logic/noise_level.dart';

/// 騒音レベルの目安を縦スケールで示す図。3段階の色帯・実例・(あれば)計測値を重ねる。
class NoiseScaleChart extends StatelessWidget {
  const NoiseScaleChart({super.key, this.measuredDb});

  /// 指定すると、スケール上に計測値の位置を重ねて表示する。
  final double? measuredDb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 300 / 420,
      child: CustomPaint(
        painter: _NoiseScalePainter(
          measuredDb: measuredDb,
          quiet: scheme.secondary,
          moderate: scheme.primary,
          loud: scheme.tertiary,
          ink: scheme.onSurface,
          muted: scheme.outline,
          surface: scheme.surface,
        ),
      ),
    );
  }
}

class _NoiseScalePainter extends CustomPainter {
  _NoiseScalePainter({
    required this.measuredDb,
    required this.quiet,
    required this.moderate,
    required this.loud,
    required this.ink,
    required this.muted,
    required this.surface,
  });

  final double? measuredDb;
  final Color quiet;
  final Color moderate;
  final Color loud;
  final Color ink;
  final Color muted;
  final Color surface;

  static const _dbMin = 20.0;
  static const _dbMax = 90.0;
  static const _axisSteps = [20, 30, 40, 50, 60, 70, 80, 90];

  @override
  void paint(Canvas canvas, Size size) {
    final barLeft = size.width * 0.22;
    final barWidth = size.width * 0.11;
    const padT = 10.0;
    const padB = 10.0;
    final trackTop = padT;
    final trackBottom = size.height - padB;
    final trackHeight = trackBottom - trackTop;

    double y(double db) =>
        trackTop + trackHeight * (1 - (db - _dbMin) / (_dbMax - _dbMin));

    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(barLeft, trackTop, barLeft + barWidth, trackBottom),
      Radius.circular(barWidth / 2),
    );

    canvas.save();
    canvas.clipRRect(barRect);
    void band(double dbLow, double dbHigh, Color color) {
      canvas.drawRect(
        Rect.fromLTRB(barLeft, y(dbHigh), barLeft + barWidth, y(dbLow)),
        Paint()..color = color,
      );
    }

    band(_dbMin, quietThresholdDb, quiet);
    band(quietThresholdDb, loudThresholdDb, moderate);
    band(loudThresholdDb, _dbMax, loud);
    canvas.restore();

    // 区分の境目を白線で分ける。
    final dividerPaint = Paint()
      ..color = surface
      ..strokeWidth = 2.5;
    for (final threshold in [quietThresholdDb, loudThresholdDb]) {
      final ty = y(threshold);
      canvas.drawLine(
        Offset(barLeft, ty),
        Offset(barLeft + barWidth, ty),
        dividerPaint,
      );
    }

    // 左側: dB軸の目盛り数字。
    for (final db in _axisSteps) {
      final ay = y(db.toDouble());
      canvas.drawLine(
        Offset(barLeft - 6, ay),
        Offset(barLeft, ay),
        Paint()
          ..color = muted.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        '$db',
        Offset(barLeft - 10, ay),
        muted,
        fontSize: 9,
        alignEnd: true,
      );
    }

    // 右側: 実例(何dBがどんな場所か)。
    for (final point in noiseReferencePoints) {
      final py = y(point.db);
      canvas.drawLine(
        Offset(barLeft + barWidth, py),
        Offset(barLeft + barWidth + 8, py),
        Paint()
          ..color = muted.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        '${point.db.round()}dB ${point.label}',
        Offset(barLeft + barWidth + 12, py),
        ink,
        fontSize: 10.5,
      );
    }

    // 計測値マーカー: 近い実例と重ならないよう、ラベルだけ縦にずらす。
    final measured = measuredDb;
    if (measured != null) {
      final clamped = measured.clamp(_dbMin, _dbMax);
      final my = y(clamped);
      final nearby = noiseReferencePoints.any(
        (p) => (p.db - measured).abs() < 4,
      );
      final labelY = nearby ? my - 16 : my;

      canvas.drawLine(
        Offset(barLeft - 14, my),
        Offset(barLeft + barWidth + 2, my),
        Paint()
          ..color = ink
          ..strokeWidth = 2.5,
      );
      final markerPath = Path()
        ..moveTo(barLeft - 14, my)
        ..lineTo(barLeft - 22, my - 5)
        ..lineTo(barLeft - 22, my + 5)
        ..close();
      canvas.drawPath(markerPath, Paint()..color = ink);
      _text(
        canvas,
        'あなたの計測値 ${measured.round()}dB',
        Offset(barLeft - 26, labelY),
        ink,
        fontSize: 10.5,
        bold: true,
        alignEnd: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    double fontSize = 10,
    bool bold = false,
    bool alignEnd = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = alignEnd
        ? anchor - Offset(painter.width, painter.height / 2)
        : anchor - Offset(0, painter.height / 2);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _NoiseScalePainter oldDelegate) {
    return oldDelegate.measuredDb != measuredDb;
  }
}
