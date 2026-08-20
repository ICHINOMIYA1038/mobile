import 'package:flutter/material.dart';

import '../../models/band_level.dart';
import '../chart_colors.dart';

/// 周波数帯域別レベル。バー=最小〜最大の範囲、太線マーカー=平均(Leq)。
/// 最大帯域には直接ラベルを添える(ラベルは値ごとにではなく主役だけ)。
class FrequencyRangeChart extends StatelessWidget {
  const FrequencyRangeChart({super.key, required this.bands});

  final List<BandLevel> bands;

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 300 / 190,
      child: CustomPaint(
        painter: _FrequencyChartPainter(
          bands: bands,
          colors: ChartColors.of(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

class _FrequencyChartPainter extends CustomPainter {
  _FrequencyChartPainter({required this.bands, required this.colors});

  final List<BandLevel> bands;
  final ChartColors colors;

  static const _dbMin = 20.0;
  static const _dbMax = 80.0;
  static const _gridSteps = [20.0, 40.0, 60.0, 80.0];

  double _y(double db, double padT, double plotH) =>
      padT + plotH * (1 - (db.clamp(_dbMin, _dbMax) - _dbMin) / (_dbMax - _dbMin));

  @override
  void paint(Canvas canvas, Size size) {
    final padL = size.width * 0.09;
    const padR = 6.0;
    const padT = 12.0;
    final padB = size.height * 0.14;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (final db in _gridSteps) {
      final gy = _y(db, padT, plotH);
      canvas.drawLine(Offset(padL, gy), Offset(size.width - padR, gy), gridPaint);
      _text(
        canvas,
        db.round().toString(),
        Offset(padL - 6, gy),
        colors.muted,
        align: TextAlign.right,
      );
    }

    final n = bands.length;
    final slot = plotW / n;
    final barW = (slot * 0.5).clamp(0.0, 24.0);

    var loudest = 0;
    for (var i = 1; i < bands.length; i++) {
      if (bands[i].leqDb > bands[loudest].leqDb) loudest = i;
    }

    final rangePaint = Paint()..color = colors.rangeFill;
    final markPaint = Paint()
      ..color = colors.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < bands.length; i++) {
      final band = bands[i];
      final cx = padL + slot * (i + 0.5);
      final top = _y(band.peakDb, padT, plotH);
      final bottom = _y(band.minDb, padT, plotH);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, rangePaint);

      final avgY = _y(band.leqDb, padT, plotH);
      canvas.drawLine(
        Offset(cx - barW / 2 - 2, avgY),
        Offset(cx + barW / 2 + 2, avgY),
        markPaint,
      );

      _text(
        canvas,
        _formatHz(band.centerHz),
        Offset(cx, size.height - padB + 14),
        colors.muted,
        align: TextAlign.center,
      );

      if (i == loudest) {
        _text(
          canvas,
          '${band.leqDb.round()}dB',
          Offset(cx, top - 12),
          colors.ink,
          align: TextAlign.center,
          bold: true,
        );
      }
    }
  }

  String _formatHz(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return hz.toStringAsFixed(0);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    TextAlign align = TextAlign.left,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: bold ? 11 : 9,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset offset;
    switch (align) {
      case TextAlign.center:
        offset = anchor - Offset(painter.width / 2, painter.height / 2);
      case TextAlign.right:
        offset = anchor - Offset(painter.width, painter.height / 2);
      default:
        offset = anchor;
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FrequencyChartPainter oldDelegate) {
    return oldDelegate.bands != bands || oldDelegate.colors != colors;
  }
}
