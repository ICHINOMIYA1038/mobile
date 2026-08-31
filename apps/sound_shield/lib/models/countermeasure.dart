/// 音が入ってくる経路。対策の適用先を絞るのに使う。
enum NoiseRoute {
  window('窓'),
  wall('壁'),
  door('ドア'),
  floor('床'),
  source('発生源'),
  personal('自分の耳');

  const NoiseRoute(this.label);

  final String label;
}

/// 対策1件分の定量データ。
///
/// [attenuationDb] はオクターブバンド(31.5Hz〜16kHz の10帯域)ごとの
/// おおよその減衰量。メーカー公表値・防音専門店の実測記事・建築音響の
/// 一般値をもとにした目安で、施工状態で大きく変わる。
class Countermeasure {
  const Countermeasure({
    required this.id,
    required this.name,
    required this.routes,
    required this.attenuationDb,
    required this.costMinMan,
    required this.costMaxMan,
    required this.summary,
    required this.evidence,
    this.caveat,
    this.sourceKeywords = const [],
    this.diy = true,
  });

  final String id;
  final String name;
  final Set<NoiseRoute> routes;
  final List<double> attenuationDb;
  final double costMinMan;
  final double costMaxMan;
  final String summary;

  /// 減衰量の根拠(出典・実測条件)。UI に「根拠」として表示する。
  final String evidence;

  /// 「効かないケース」の正直な注意書き。
  final String? caveat;

  /// 空でなければ、検出音のラベルにこれらが含まれるときだけ候補に入れる
  /// (防振ゴムは機械音、防音マットは足音、など)。
  final List<String> sourceKeywords;

  /// 自分で設置できるか(工事不要か)。
  final bool diy;

  String get costLabel {
    if (costMinMan == 0 && costMaxMan == 0) return '無料';
    String fmt(double v) =>
        v < 1 ? '${(v * 10000).round()}円' : '${v % 1 == 0 ? v.toInt() : v}万円';
    return '${fmt(costMinMan)}〜${fmt(costMaxMan)}';
  }
}

/// 対策を適用した場合の予測。
class CountermeasurePrediction {
  const CountermeasurePrediction({
    required this.measure,
    required this.beforeDb,
    required this.afterDb,
    required this.beforeBands,
    required this.afterBands,
    required this.matchesRoute,
    required this.verdict,
    required this.reason,
  });

  final Countermeasure measure;
  final double beforeDb;
  final double afterDb;
  final List<double> beforeBands;
  final List<double> afterBands;

  /// 推定された侵入経路に合っている対策か。
  final bool matchesRoute;
  final PredictionVerdict verdict;

  /// verdict の一言説明(「低音中心のため効果薄」など)。
  final String reason;

  double get deltaDb => beforeDb - afterDb;
}

enum PredictionVerdict {
  none('効果はほぼ期待できない'),
  small('わずかな効果'),
  medium('中程度の効果'),
  large('大きな効果');

  const PredictionVerdict(this.label);

  final String label;
}
