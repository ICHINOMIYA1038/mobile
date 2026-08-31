/// ノック音・手叩きのような衝撃音1発の解析結果(ネイティブ ImpulseProbe の出力)。
class ImpulseResult {
  const ImpulseResult({
    required this.peakDb,
    required this.floorDb,
    required this.snrDb,
    required this.t10,
    required this.t20,
    required this.rt60,
    required this.spectralCentroidHz,
    required this.lowShare,
    required this.highShare,
    required this.peakHz,
  });

  final double peakDb;
  final double floorDb;
  final double snrDb;

  /// ピークから -10dB / -20dB まで減衰するのにかかった秒数。床に埋もれて測れなければ null。
  final double? t10;
  final double? t20;

  /// T20×3 (無ければ T10×6) で外挿した残響時間(秒)。
  final double? rt60;

  /// 立ち上がり直後約85msのスペクトル重心(Hz)。高いほど「軽い・乾いた」音。
  final double spectralCentroidHz;
  final double lowShare;
  final double highShare;
  final double peakHz;

  factory ImpulseResult.fromMap(Map<Object?, Object?> map) {
    double? optional(Object? v) => v == null ? null : (v as num).toDouble();
    return ImpulseResult(
      peakDb: (map['peakDb'] as num).toDouble(),
      floorDb: (map['floorDb'] as num).toDouble(),
      snrDb: (map['snrDb'] as num).toDouble(),
      t10: optional(map['t10']),
      t20: optional(map['t20']),
      rt60: optional(map['rt60']),
      spectralCentroidHz: (map['spectralCentroidHz'] as num).toDouble(),
      lowShare: (map['lowShare'] as num).toDouble(),
      highShare: (map['highShare'] as num).toDouble(),
      peakHz: (map['peakHz'] as num).toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'peakDb': peakDb,
    'floorDb': floorDb,
    'snrDb': snrDb,
    't10': t10,
    't20': t20,
    'rt60': rt60,
    'spectralCentroidHz': spectralCentroidHz,
    'lowShare': lowShare,
    'highShare': highShare,
    'peakHz': peakHz,
  };
}
