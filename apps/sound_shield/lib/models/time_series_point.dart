/// 計測中のある時点(t秒)における目安dB値。
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.t, required this.db});

  final double t;
  final double db;

  factory TimeSeriesPoint.fromMap(Map<Object?, Object?> map) {
    return TimeSeriesPoint(
      t: (map['t'] as num).toDouble(),
      db: (map['db'] as num).toDouble(),
    );
  }
}
