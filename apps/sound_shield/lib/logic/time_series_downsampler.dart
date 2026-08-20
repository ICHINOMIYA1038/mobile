import '../models/time_series_point.dart';

/// 折れ線描画用に間引いた点列を作る。ピーク/最小の探索には使わない
/// (間引きで一瞬のスパイクが鈍る可能性があるため、元データ全体から探す)。
List<TimeSeriesPoint> downsampleForLine(
  List<TimeSeriesPoint> series, {
  int maxPoints = 180,
}) {
  if (series.length <= maxPoints) return series;
  final bucketSize = series.length / maxPoints;
  final result = <TimeSeriesPoint>[];
  for (var i = 0; i < maxPoints; i++) {
    final start = (i * bucketSize).floor();
    final end = ((i + 1) * bucketSize).floor().clamp(start + 1, series.length);
    final bucket = series.sublist(start, end);
    final avgT = bucket.map((p) => p.t).reduce((a, b) => a + b) / bucket.length;
    final avgDb = bucket.map((p) => p.db).reduce((a, b) => a + b) / bucket.length;
    result.add(TimeSeriesPoint(t: avgT, db: avgDb));
  }
  return result;
}

const _niceAxisSteps = <double>[
  5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600,
];

/// 見やすい間隔(5秒刻み〜1時間刻み)でx軸目盛りの時刻を作る。
/// 「時間を指定」の短い計測(15秒など)から「止めるまで測定」の長時間計測まで
/// おおよそ4〜8本の目盛りに収まるようにする。
List<double> axisTicks(double durationSeconds) {
  if (durationSeconds <= 0) return const [0];
  final rawStep = durationSeconds / 4;
  final step = _niceAxisSteps.firstWhere(
    (s) => s >= rawStep,
    orElse: () => _niceAxisSteps.last,
  );
  final ticks = <double>[];
  for (var t = 0.0; t <= durationSeconds + 0.01; t += step) {
    ticks.add(t);
  }
  return ticks;
}

/// x軸ラベルの表記。90秒未満は秒、それ以上は分に丸める。
String formatAxisLabel(double seconds) {
  if (seconds < 90) return '${seconds.round()}s';
  final minutes = (seconds / 60).round();
  return '$minutes分';
}
