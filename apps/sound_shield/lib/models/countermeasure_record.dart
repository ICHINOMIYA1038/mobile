import 'measurement_result.dart';

/// 対策の Before/After 記録。対策前の計測に対して、実施後にもう一度
/// 同じ場所で計測して効果を確かめる。
class CountermeasureRecord {
  const CountermeasureRecord({
    required this.id,
    required this.measureId,
    required this.measureName,
    required this.createdAt,
    required this.before,
    this.after,
    this.predictedDeltaDb,
    this.place = '',
  });

  final String id;
  final String measureId;
  final String measureName;
  final DateTime createdAt;
  final MeasurementResult before;
  final MeasurementResult? after;

  /// シミュレーターが出した予測ΔdB(あれば)。実測との比較に使う。
  final double? predictedDeltaDb;
  final String place;

  double? get actualDeltaDb =>
      after == null ? null : before.overallLeqDb - after!.overallLeqDb;

  CountermeasureRecord copyWith({MeasurementResult? after, String? place}) {
    return CountermeasureRecord(
      id: id,
      measureId: measureId,
      measureName: measureName,
      createdAt: createdAt,
      before: before,
      after: after ?? this.after,
      predictedDeltaDb: predictedDeltaDb,
      place: place ?? this.place,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'measureId': measureId,
    'measureName': measureName,
    'createdAt': createdAt.toIso8601String(),
    'before': before.toJson(),
    'after': after?.toJson(),
    'predictedDeltaDb': predictedDeltaDb,
    'place': place,
  };

  factory CountermeasureRecord.fromJson(Map<String, Object?> json) {
    return CountermeasureRecord(
      id: json['id'] as String,
      measureId: json['measureId'] as String,
      measureName: json['measureName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      before: MeasurementResult.fromMap(json['before'] as Map<Object?, Object?>),
      after: json['after'] == null
          ? null
          : MeasurementResult.fromMap(json['after'] as Map<Object?, Object?>),
      predictedDeltaDb: (json['predictedDeltaDb'] as num?)?.toDouble(),
      place: (json['place'] as String?) ?? '',
    );
  }
}
