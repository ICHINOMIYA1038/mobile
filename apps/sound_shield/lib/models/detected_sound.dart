/// SNSoundClassifierが検出した音源ラベル1件分。
class DetectedSound {
  const DetectedSound({
    required this.identifier,
    required this.activeShare,
    required this.avgConfidence,
  });

  /// SoundAnalysisフレームワークの分類識別子(例: "vehicle_engine")。
  final String identifier;

  /// 計測時間のうち、このラベルが信頼度しきい値以上で検出されていた割合(0.0〜1.0)。
  final double activeShare;

  /// 検出されていた区間の平均信頼度(0.0〜1.0)。
  final double avgConfidence;

  factory DetectedSound.fromMap(Map<Object?, Object?> map) {
    return DetectedSound(
      identifier: map['identifier'] as String,
      activeShare: (map['activeShare'] as num).toDouble(),
      avgConfidence: (map['avgConfidence'] as num).toDouble(),
    );
  }
}
