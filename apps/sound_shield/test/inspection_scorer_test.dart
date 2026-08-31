import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/logic/inspection_scorer.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/countermeasure.dart';
import 'package:sound_shield/models/impulse_result.dart';
import 'package:sound_shield/models/inspection.dart';
import 'package:sound_shield/models/measurement_result.dart';

MeasurementResult _m(double leq, {double low = 40, double high = 40}) {
  return MeasurementResult(
    durationSeconds: 15,
    overallLeqDb: leq,
    overallPeakDb: leq + 10,
    overallMinDb: leq - 10,
    bands: [
      BandLevel(centerHz: 125, leqDb: low, peakDb: low, minDb: low),
      BandLevel(centerHz: 1000, leqDb: leq, peakDb: leq, minDb: leq),
      BandLevel(centerHz: 4000, leqDb: high, peakDb: high, minDb: high),
    ],
    soundLabels: const [],
  );
}

ImpulseResult _knock({
  required double centroid,
  double? t20,
  double snr = 25,
  double? rt60,
  double lowShare = 0.5,
}) {
  return ImpulseResult(
    peakDb: 80,
    floorDb: 80 - snr,
    snrDb: snr,
    t10: t20 == null ? null : t20 / 2,
    t20: t20,
    rt60: rt60 ?? (t20 == null ? null : t20 * 3),
    spectralCentroidHz: centroid,
    lowShare: lowShare,
    highShare: 0.2,
    peakHz: centroid,
  );
}

Inspection _inspection({
  MeasurementResult? ambient,
  MeasurementResult? window,
  ImpulseResult? knock,
  ImpulseResult? clap,
  MeasurementResult? neighbor,
}) {
  return Inspection(
    id: 'x',
    name: 'test',
    createdAt: DateTime(2026, 8, 28),
    ambient: ambient,
    window: window,
    knock: knock,
    clap: clap,
    neighbor: neighbor,
  );
}

void main() {
  const scorer = InspectionScorer();

  test('静かでRC相当の部屋は満点に近くA', () {
    final score = scorer.score(
      _inspection(
        ambient: _m(35),
        window: _m(36),
        knock: _knock(centroid: 1500, t20: 0.04, lowShare: 0.3),
        clap: _knock(centroid: 900, t20: 0.1, rt60: 0.4),
        neighbor: _m(35),
      ),
    );
    expect(score.score, greaterThanOrEqualTo(95));
    expect(score.grade, 'A');
    expect(score.wall, WallEstimate.heavy);
    expect(score.weakest, isNull);
    expect(score.measuredSteps, 5);
  });

  test('窓際が中央より大きく、壁が軽いと弱点が窓になり経路に窓が入る', () {
    final score = scorer.score(
      _inspection(
        ambient: _m(45),
        window: _m(58, high: 60),
        knock: _knock(centroid: 220, t20: 0.15, lowShare: 0.9),
        neighbor: _m(46),
      ),
    );
    expect(score.wall, WallEstimate.light);
    expect(score.weakest!.key, 'window');
    expect(score.routes.first, NoiseRoute.window);
    expect(score.routes, contains(NoiseRoute.wall));
    expect(score.score, lessThan(60));
  });

  test('SNRが低いノックは判定不能として軽い減点にとどめる', () {
    final score = scorer.score(
      _inspection(knock: _knock(centroid: 200, t20: 0.3, snr: 5)),
    );
    expect(score.wall, WallEstimate.unknown);
    expect(score.score, 95);
  });

  test('低域共振が強く余韻が中程度でも軽い壁、短く乾いた音は重い壁', () {
    expect(
      WallEstimate.fromKnock(_knock(centroid: 220, t20: 0.08, lowShare: 0.95)),
      WallEstimate.light,
    );
    expect(
      WallEstimate.fromKnock(_knock(centroid: 900, t20: 0.03, lowShare: 0.4)),
      WallEstimate.heavy,
    );
    expect(
      WallEstimate.fromKnock(_knock(centroid: 500, t20: 0.08, lowShare: 0.5)),
      WallEstimate.medium,
    );
  });

  test('未計測のステップは減点せず、計測数だけ数える', () {
    final score = scorer.score(_inspection(ambient: _m(38)));
    expect(score.score, 100);
    expect(score.measuredSteps, 1);
  });

  test('残響が長い部屋は響きで減点される', () {
    final score = scorer.score(
      _inspection(clap: _knock(centroid: 900, t20: 0.5, rt60: 1.5)),
    );
    expect(score.components.single.key, 'reverb');
    expect(score.components.single.penalty, 10);
  });
}
