/// ARマップで記録した1点分のサンプル(端末位置と、その場所のレベル)。
class ArNoiseSample {
  const ArNoiseSample({
    required this.x,
    required this.y,
    required this.z,
    required this.db,
    required this.lowDb,
    required this.midDb,
    required this.highDb,
    required this.tag,
  });

  final double x;
  final double y;
  final double z;
  final double db;
  final double lowDb;
  final double midDb;
  final double highDb;

  /// 計測中にユーザーが選んだ場所ラベル(ArSurface.name か 'untagged')。
  final String tag;

  factory ArNoiseSample.fromMap(Map<Object?, Object?> map) {
    return ArNoiseSample(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      db: (map['db'] as num).toDouble(),
      lowDb: (map['lowDb'] as num).toDouble(),
      midDb: (map['midDb'] as num).toDouble(),
      highDb: (map['highDb'] as num).toDouble(),
      tag: (map['tag'] as String?) ?? 'untagged',
    );
  }
}

/// ARマップ計測中に端末をかざしている面。
enum ArSurface {
  window('窓'),
  wall('壁'),
  door('ドア'),
  floor('床・天井'),
  center('部屋の中央');

  const ArSurface(this.label);

  final String label;
}
