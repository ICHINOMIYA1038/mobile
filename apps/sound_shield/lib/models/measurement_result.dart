import 'band_level.dart';
import 'detected_sound.dart';
import 'sound_segment.dart';
import 'time_series_point.dart';

/// 1回の騒音計測の集計結果。
class MeasurementResult {
  const MeasurementResult({
    required this.durationSeconds,
    required this.overallLeqDb,
    required this.overallPeakDb,
    required this.overallMinDb,
    required this.bands,
    required this.soundLabels,
    this.timeSeries = const [],
    this.soundTimeline = const [],
  });

  final int durationSeconds;

  /// 目安値(相対dB)。キャリブレーション未実施のため絶対SPLではない。
  final double overallLeqDb;
  final double overallPeakDb;
  final double overallMinDb;
  final List<BandLevel> bands;

  /// activeShare降順。対策提案・「検出された音」一覧に使う集計済みラベル。
  final List<DetectedSound> soundLabels;

  /// 計測時間軸上のdB推移(時系列グラフ用)。t昇順。
  final List<TimeSeriesPoint> timeSeries;

  /// 時間軸に重ね合わせる生の音源セグメント(グラフのオーバーレイ用)。重複区間を含みうる。
  final List<SoundSegment> soundTimeline;

  factory MeasurementResult.fromMap(Map<Object?, Object?> map) {
    final bandsRaw = (map['bands'] as List?) ?? const [];
    final labelsRaw = (map['soundLabels'] as List?) ?? const [];
    final timeSeriesRaw = (map['timeSeries'] as List?) ?? const [];
    final timelineRaw = (map['soundTimeline'] as List?) ?? const [];
    return MeasurementResult(
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      overallLeqDb: (map['overallLeqDb'] as num).toDouble(),
      overallPeakDb: (map['overallPeakDb'] as num).toDouble(),
      overallMinDb: (map['overallMinDb'] as num).toDouble(),
      bands: bandsRaw
          .map((e) => BandLevel.fromMap(Map<Object?, Object?>.from(e as Map)))
          .toList(),
      soundLabels: labelsRaw
          .map(
            (e) => DetectedSound.fromMap(Map<Object?, Object?>.from(e as Map)),
          )
          .toList(),
      timeSeries: timeSeriesRaw
          .map(
            (e) =>
                TimeSeriesPoint.fromMap(Map<Object?, Object?>.from(e as Map)),
          )
          .toList(),
      soundTimeline: timelineRaw
          .map(
            (e) => SoundSegment.fromMap(Map<Object?, Object?>.from(e as Map)),
          )
          .toList(),
    );
  }

  /// Leqが最も高い帯域。周波数帯起点の対策提案に使う。
  BandLevel? get dominantBand {
    if (bands.isEmpty) return null;
    return bands.reduce((a, b) => a.leqDb >= b.leqDb ? a : b);
  }
}
