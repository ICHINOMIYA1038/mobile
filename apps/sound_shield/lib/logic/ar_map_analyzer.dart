import 'dart:math' as math;

import '../models/ar_noise_sample.dart';
import '../models/countermeasure.dart';

/// 場所ラベルごとの集計。
class SurfaceStat {
  const SurfaceStat({
    required this.surface,
    required this.count,
    required this.meanDb,
    required this.maxDb,
    required this.lowShare,
  });

  final ArSurface? surface;
  final int count;

  /// パワー平均(エネルギー平均)のdB。
  final double meanDb;
  final double maxDb;

  /// 低域(<500Hz)の割合。0.5超なら「低音中心」。
  final double lowShare;

  String get label => surface?.label ?? '未分類';
}

class ArMapAnalysis {
  const ArMapAnalysis({
    required this.stats,
    required this.overallMeanDb,
    required this.minDb,
    required this.maxDb,
  });

  final List<SurfaceStat> stats;
  final double overallMeanDb;
  final double minDb;
  final double maxDb;

  /// 平均が最も高い面(=主な侵入経路)。「部屋の中央」と未分類は経路ではないので除く。
  SurfaceStat? get hottest {
    for (final s in stats) {
      if (s.surface != null && s.surface != ArSurface.center) return s;
    }
    return null;
  }

  /// 平均の高い順に、対策シミュレーターへ渡す侵入経路(最大2つ)。
  List<NoiseRoute> get routes {
    final routes = <NoiseRoute>[];
    for (final s in stats) {
      final r = switch (s.surface) {
        ArSurface.window => NoiseRoute.window,
        ArSurface.wall => NoiseRoute.wall,
        ArSurface.door => NoiseRoute.door,
        ArSurface.floor => NoiseRoute.floor,
        _ => null,
      };
      if (r != null && !routes.contains(r)) routes.add(r);
      if (routes.length == 2) break;
    }
    return routes;
  }
}

/// ARマップのサンプルを面ごとに集計する。位置(x,y,z)は AR 座標系で
/// ユーザーには意味がないので、集計は「どの面にかざしていたか」のタグで行う。
class ArMapAnalyzer {
  const ArMapAnalyzer();

  ArMapAnalysis analyze(List<ArNoiseSample> samples) {
    if (samples.isEmpty) {
      return const ArMapAnalysis(
        stats: [],
        overallMeanDb: 0,
        minDb: 0,
        maxDb: 0,
      );
    }
    final groups = <String, List<ArNoiseSample>>{};
    for (final s in samples) {
      groups.putIfAbsent(s.tag, () => []).add(s);
    }
    final stats = <SurfaceStat>[];
    for (final entry in groups.entries) {
      final list = entry.value;
      var lowPower = 0.0;
      var totalPower = 0.0;
      for (final s in list) {
        final low = _pow10(s.lowDb);
        lowPower += low;
        totalPower += low + _pow10(s.midDb) + _pow10(s.highDb);
      }
      stats.add(
        SurfaceStat(
          surface: ArSurface.values
              .where((v) => v.name == entry.key)
              .firstOrNull,
          count: list.length,
          meanDb: _energyMeanDb(list.map((s) => s.db)),
          maxDb: list.map((s) => s.db).reduce(math.max),
          lowShare: totalPower > 0 ? lowPower / totalPower : 0,
        ),
      );
    }
    stats.sort((a, b) => b.meanDb.compareTo(a.meanDb));
    final dbs = samples.map((s) => s.db).toList();
    return ArMapAnalysis(
      stats: stats,
      overallMeanDb: _energyMeanDb(dbs),
      minDb: dbs.reduce(math.min),
      maxDb: dbs.reduce(math.max),
    );
  }

  static double _pow10(double db) => math.pow(10, db / 10).toDouble();

  static double _energyMeanDb(Iterable<double> dbs) {
    var sum = 0.0;
    var n = 0;
    for (final db in dbs) {
      sum += _pow10(db);
      n++;
    }
    if (n == 0 || sum <= 0) return 0;
    return 10 * math.log(sum / n) / math.ln10;
  }
}
