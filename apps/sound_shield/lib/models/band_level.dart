/// オクターブバンド1本分のレベル。
class BandLevel {
  const BandLevel({
    required this.centerHz,
    required this.leqDb,
    required this.peakDb,
    required this.minDb,
  });

  final double centerHz;
  final double leqDb;
  final double peakDb;
  final double minDb;

  factory BandLevel.fromMap(Map<Object?, Object?> map) {
    return BandLevel(
      centerHz: (map['centerHz'] as num).toDouble(),
      leqDb: (map['leqDb'] as num).toDouble(),
      peakDb: (map['peakDb'] as num).toDouble(),
      minDb: (map['minDb'] as num).toDouble(),
    );
  }
}
