import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/models/measurement_result.dart';

void main() {
  test('Mapからbands/soundLabels/timeSeries/soundTimelineを含めて正しくパースできる', () {
    final result = MeasurementResult.fromMap({
      'durationSeconds': 15,
      'overallLeqDb': 62.3,
      'overallPeakDb': 78.1,
      'overallMinDb': 41.5,
      'bands': [
        {'centerHz': 31.5, 'leqDb': 50.0, 'peakDb': 55.0, 'minDb': 44.0},
        {'centerHz': 1000.0, 'leqDb': 65.0, 'peakDb': 70.0, 'minDb': 58.0},
      ],
      'soundLabels': [
        {
          'identifier': 'vehicle_engine',
          'activeShare': 0.42,
          'avgConfidence': 0.71,
        },
      ],
      'timeSeries': [
        {'t': 0.0, 'db': 45.0},
        {'t': 1.0, 'db': 62.3},
      ],
      'soundTimeline': [
        {
          'startSeconds': 0.0,
          'endSeconds': 1.0,
          'identifier': 'vehicle_engine',
          'confidence': 0.71,
        },
      ],
    });

    expect(result.durationSeconds, 15);
    expect(result.overallLeqDb, 62.3);
    expect(result.overallPeakDb, 78.1);
    expect(result.overallMinDb, 41.5);
    expect(result.bands, hasLength(2));
    expect(result.bands.first.centerHz, 31.5);
    expect(result.bands.first.minDb, 44.0);
    expect(result.soundLabels.single.identifier, 'vehicle_engine');
    expect(result.soundLabels.single.activeShare, 0.42);
    expect(result.timeSeries, hasLength(2));
    expect(result.timeSeries.last.db, 62.3);
    expect(result.soundTimeline.single.identifier, 'vehicle_engine');
  });

  test('bands/soundLabels/timeSeries/soundTimelineが無いMapでも空リストとして扱う', () {
    final result = MeasurementResult.fromMap({
      'durationSeconds': 15,
      'overallLeqDb': 0.0,
      'overallPeakDb': 0.0,
      'overallMinDb': 0.0,
    });

    expect(result.bands, isEmpty);
    expect(result.soundLabels, isEmpty);
    expect(result.timeSeries, isEmpty);
    expect(result.soundTimeline, isEmpty);
    expect(result.dominantBand, isNull);
  });

  test('dominantBandはLeqが最大のバンドを返す', () {
    final result = MeasurementResult.fromMap({
      'durationSeconds': 15,
      'overallLeqDb': 0.0,
      'overallPeakDb': 0.0,
      'overallMinDb': 0.0,
      'bands': [
        {'centerHz': 31.5, 'leqDb': 50.0, 'peakDb': 55.0, 'minDb': 44.0},
        {'centerHz': 1000.0, 'leqDb': 65.0, 'peakDb': 70.0, 'minDb': 58.0},
        {'centerHz': 8000.0, 'leqDb': 40.0, 'peakDb': 45.0, 'minDb': 34.0},
      ],
      'soundLabels': [],
    });

    expect(result.dominantBand!.centerHz, 1000.0);
  });
}
