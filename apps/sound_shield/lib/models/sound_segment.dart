/// 計測時間軸上で、ある区間に検出されていた音源ラベル1件分(重ね合わせグラフ用)。
class SoundSegment {
  const SoundSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.identifier,
    required this.confidence,
  });

  final double startSeconds;
  final double endSeconds;
  final String identifier;
  final double confidence;

  factory SoundSegment.fromMap(Map<Object?, Object?> map) {
    return SoundSegment(
      startSeconds: (map['startSeconds'] as num).toDouble(),
      endSeconds: (map['endSeconds'] as num).toDouble(),
      identifier: map['identifier'] as String,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }
}
