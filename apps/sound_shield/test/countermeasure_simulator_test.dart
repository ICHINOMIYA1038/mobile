import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/logic/countermeasure_simulator.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/countermeasure.dart';
import 'package:sound_shield/models/detected_sound.dart';
import 'package:sound_shield/models/measurement_result.dart';

const _centers = [31.5, 63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];

MeasurementResult _result(List<double> bands, {List<String> labels = const []}) {
  return MeasurementResult(
    durationSeconds: 15,
    overallLeqDb: MeasurementResult.overallFromBands(bands),
    overallPeakDb: 80,
    overallMinDb: 30,
    bands: [
      for (var i = 0; i < bands.length; i++)
        BandLevel(centerHz: _centers[i], leqDb: bands[i], peakDb: bands[i], minDb: bands[i]),
    ],
    soundLabels: [
      for (final l in labels)
        DetectedSound(identifier: l, activeShare: 0.5, avgConfidence: 0.8),
    ],
  );
}

void main() {
  const sim = CountermeasureSimulator();

  test('高音中心の話し声には防音カーテンが効き、内窓はさらに効く', () {
    final r = _result([30, 32, 36, 44, 52, 58, 60, 56, 48, 40], labels: ['speech']);
    final preds = sim.predict(r);
    final curtain = preds.firstWhere((p) => p.measure.id == 'curtain');
    final inner = preds.firstWhere((p) => p.measure.id == 'inner_window');
    expect(curtain.deltaDb, greaterThan(2));
    expect(inner.deltaDb, greaterThan(curtain.deltaDb));
    expect(curtain.verdict, isNot(PredictionVerdict.none));
  });

  test('低音中心の交通音では防音カーテンは「効かない」と正直に出す', () {
    final r = _result([62, 66, 64, 58, 50, 44, 38, 34, 30, 30], labels: ['traffic_vehicle']);
    final preds = sim.predict(r);
    final curtain = preds.firstWhere((p) => p.measure.id == 'curtain');
    expect(curtain.deltaDb, lessThan(1));
    expect(curtain.verdict, PredictionVerdict.none);
    expect(curtain.reason, contains('低い音'));
    expect(CountermeasureSimulator.inferRoutes(r), contains(NoiseRoute.wall));
  });

  test('音源が機械音でなければ防振ゴムは候補に出ない', () {
    final r = _result([40, 42, 44, 46, 50, 52, 50, 46, 40, 36], labels: ['speech']);
    expect(sim.predict(r).any((p) => p.measure.id == 'vibration_pad'), isFalse);
    final mech = _result([50, 52, 50, 46, 42, 40, 38, 36, 34, 30], labels: ['air_conditioner']);
    expect(sim.predict(mech).any((p) => p.measure.id == 'vibration_pad'), isTrue);
  });

  test('指定した経路に合う対策が先に並ぶ', () {
    final r = _result([40, 42, 46, 50, 54, 56, 54, 50, 44, 38]);
    final preds = sim.predict(r, routes: [NoiseRoute.door]);
    expect(preds.first.matchesRoute, isTrue);
    expect(preds.first.measure.routes, anyOf(contains(NoiseRoute.door), contains(NoiseRoute.personal)));
  });

  test('床(30dB)より下には下がらない', () {
    final r = _result([31, 31, 31, 31, 31, 31, 31, 31, 31, 31]);
    for (final p in sim.predict(r)) {
      expect(p.afterBands.every((b) => b >= CountermeasureSimulator.floorDb - 1e-9), isTrue);
    }
  });
}
