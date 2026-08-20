import 'package:flutter/material.dart';

import '../../logic/time_series_downsampler.dart';
import '../../models/time_series_point.dart';
import '../chart_colors.dart';

/// 計測時間内のdB推移。折れ線+面塗り、ピーク/最小を直接ラベルする。
/// 「止めるまで測定」の長時間データにも対応するため、線の描画点数は間引くが
/// ピーク/最小は元データ全体から探すため精度は落ちない。
class TimeSeriesChart extends StatelessWidget {
  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.durationSeconds,
  });

  final List<TimeSeriesPoint> series;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 300 / 150,
      child: CustomPaint(
        painter: _TimeSeriesChartPainter(
          series: series,
          durationSeconds: durationSeconds,
          colors: ChartColors.of(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

class _TimeSeriesChartPainter extends CustomPainter {
  _TimeSeriesChartPainter({
    required this.series,
    required this.durationSeconds,
    required this.colors,
  });

  final List<TimeSeriesPoint> series;
  final int durationSeconds;
  final ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final padL = size.width * 0.09;
    final padR = size.width * 0.05;
    const padT = 14.0;
    final padB = size.height * 0.16;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final duration = durationSeconds > 0 ? durationSeconds.toDouble() : 1.0;

    final dbs = series.map((p) => p.db);
    final rawMin = dbs.reduce((a, b) => a < b ? a : b);
    final rawMax = dbs.reduce((a, b) => a > b ? a : b);
    final dbMin = (rawMin / 10).floor() * 10 - 5;
    final dbMax = (rawMax / 10).ceil() * 10 + 5;
    final dbRange = (dbMax - dbMin).clamp(1, double.infinity);

    double x(double t) => padL + plotW * (t / duration);
    double y(double db) => padT + plotH * (1 - (db - dbMin) / dbRange);

    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    final midDb = ((dbMin + dbMax) / 2 / 5).round() * 5;
    for (final db in {dbMin, midDb, dbMax}) {
      final gy = y(db.toDouble());
      canvas.drawLine(Offset(padL, gy), Offset(size.width - padR, gy), gridPaint);
      _text(canvas, db.round().toString(), Offset(padL - 6, gy), colors.muted, alignRight: true);
    }
    for (final t in axisTicks(duration)) {
      _text(
        canvas,
        formatAxisLabel(t),
        Offset(x(t), size.height - padB + 14),
        colors.muted,
        alignCenter: true,
      );
    }

    final lineSeries = downsampleForLine(series);
    final path = Path();
    for (var i = 0; i < lineSeries.length; i++) {
      final p = Offset(x(lineSeries[i].t), y(lineSeries[i].db));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final areaPath = Path.from(path)
      ..lineTo(x(lineSeries.last.t), padT + plotH)
      ..lineTo(x(lineSeries.first.t), padT + plotH)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = colors.areaFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ピーク/最小は間引く前の全データから探す(ダウンサンプルで鈍らせない)。
    var maxP = series.first;
    var minP = series.first;
    for (final p in series) {
      if (p.db > maxP.db) maxP = p;
      if (p.db < minP.db) minP = p;
    }

    for (final entry in [(maxP, 'ピーク', -10.0), (minP, '最小', 16.0)]) {
      final (point, label, dy) = entry;
      final center = Offset(x(point.t), y(point.db));
      canvas.drawCircle(center, 4.5, Paint()..color = colors.surface);
      canvas.drawCircle(center, 3.5, Paint()..color = colors.accent);
      final atStart = center.dx < padL + 46;
      final atEnd = center.dx > size.width - padR - 46;
      _text(
        canvas,
        '$label ${point.db.round()}dB',
        Offset(center.dx, center.dy + dy),
        colors.ink,
        alignCenter: !atStart && !atEnd,
        alignRight: atEnd,
        bold: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    bool alignCenter = false,
    bool alignRight = false,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: bold ? 10.5 : 9,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset offset;
    if (alignCenter) {
      offset = anchor - Offset(painter.width / 2, painter.height / 2);
    } else if (alignRight) {
      offset = anchor - Offset(painter.width, painter.height / 2);
    } else {
      offset = anchor - Offset(0, painter.height / 2);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.colors != colors;
  }
}
