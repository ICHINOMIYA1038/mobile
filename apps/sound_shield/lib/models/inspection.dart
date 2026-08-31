import 'impulse_result.dart';
import 'measurement_result.dart';

/// 内見モードの計測ステップ。順番どおりに画面が進む。
enum InspectionStep {
  ambient('室内の静けさ', '部屋の中央に立ち、窓とドアを閉めて計測します。'),
  window('窓からの音', '窓を閉めたまま、窓から30cmの位置で計測します。'),
  knock('壁のノック', '端末を壁から30cm以内に持ち、隣室側の壁を指の関節で軽く1回「コン」と叩きます。大きく叩く必要はありません。'),
  clap('部屋の響き', '部屋の中央で1回だけ手を叩きます。'),
  neighbor('隣室・廊下側', '隣室側の壁またはドアから30cmの位置で計測します。');

  const InspectionStep(this.title, this.instruction);

  final String title;
  final String instruction;

  bool get isImpulse => this == knock || this == clap;
}

/// 1物件(1部屋)分の内見診断。
class Inspection {
  const Inspection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.memo = '',
    this.ambient,
    this.window,
    this.knock,
    this.clap,
    this.neighbor,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String memo;
  final MeasurementResult? ambient;
  final MeasurementResult? window;
  final ImpulseResult? knock;
  final ImpulseResult? clap;
  final MeasurementResult? neighbor;

  bool get hasAnyData =>
      ambient != null ||
      window != null ||
      knock != null ||
      clap != null ||
      neighbor != null;

  Inspection copyWith({
    String? name,
    String? memo,
    MeasurementResult? ambient,
    MeasurementResult? window,
    ImpulseResult? knock,
    ImpulseResult? clap,
    MeasurementResult? neighbor,
  }) {
    return Inspection(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      memo: memo ?? this.memo,
      ambient: ambient ?? this.ambient,
      window: window ?? this.window,
      knock: knock ?? this.knock,
      clap: clap ?? this.clap,
      neighbor: neighbor ?? this.neighbor,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'memo': memo,
    'ambient': ambient?.toJson(),
    'window': window?.toJson(),
    'knock': knock?.toJson(),
    'clap': clap?.toJson(),
    'neighbor': neighbor?.toJson(),
  };

  factory Inspection.fromJson(Map<String, Object?> json) {
    MeasurementResult? measurement(Object? v) =>
        v == null ? null : MeasurementResult.fromMap(v as Map<Object?, Object?>);
    ImpulseResult? impulse(Object? v) =>
        v == null ? null : ImpulseResult.fromMap(v as Map<Object?, Object?>);
    return Inspection(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      memo: (json['memo'] as String?) ?? '',
      ambient: measurement(json['ambient']),
      window: measurement(json['window']),
      knock: impulse(json['knock']),
      clap: impulse(json['clap']),
      neighbor: measurement(json['neighbor']),
    );
  }
}
