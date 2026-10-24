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
    expect(score.evaluatedSteps, 5);
    expect(score.takenSteps, 5);
    expect(score.stepsText, '測った項目 5/5');
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

  test('余韻が測れなかったノック(SNRは足りている)は重い壁ではなく判定不能', () {
    // 叩きが弱いと ImpulseAnalyzer は T10/T20 を出せない。以前は「余韻なし=重い壁」で
    // 最良判定(減点0)になっていた。
    expect(
      WallEstimate.fromKnock(_knock(centroid: 300, t20: null, snr: 12, lowShare: 0.4)),
      WallEstimate.unknown,
    );
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
    expect(score.evaluatedSteps, 1);
    expect(score.takenSteps, 1);
    expect(score.stepsText, '測った項目 1/5');
  });

  test('中央を測っていないと、窓際・隣室側は採点せず測った項目にも数えない', () {
    // 窓際・隣室側は中央との差で採点する。以前は中央が無いと差を0とみなし、
    // 減点0(=良い)で「測った項目」にも数えていた。
    final score = scorer.score(
      _inspection(
        window: _m(70, high: 72),
        knock: _knock(centroid: 900, t20: 0.03, lowShare: 0.4),
        neighbor: _m(68),
      ),
    );
    expect(score.components.map((c) => c.key), ['wall']);
    expect(score.evaluatedSteps, 1);
    expect(score.takenSteps, 3);
    expect(score.stepsText, '測った項目 3/5(評価できたのは1)');
    expect(score.notes, [InspectionScorer.needsAmbientNote]);
  });

  test('スコア順では、評価できた項目が無い記録を後ろへ並べる', () {
    final none = scorer.score(_inspection(window: _m(70)));
    final low = scorer.score(_inspection(ambient: _m(60)));
    final high = scorer.score(_inspection(ambient: _m(38)));
    // 評価なしの記録は score が 100 のままなので、点だけで並べると先頭に来ていた。
    expect(none.score, 100);
    final sorted = [none, low, high]..sort(InspectionScore.compareByScore);
    expect(sorted, [high, low, none]);
  });

  test('窓際だけ測ったときは点を出さない', () {
    final score = scorer.score(_inspection(window: _m(70)));
    expect(score.isEvaluated, isFalse);
    // 以前は評価できた数を「0/5項目を計測」と出し、測ったのに測っていないように読めた。
    expect(score.takenSteps, 1);
    expect(score.evaluatedSteps, 0);
    expect(score.stepsText, '測った項目 1/5(評価できたのは0)');
    expect(score.scoreText, '—');
    expect(score.grade, '—');
    expect(score.notes, [InspectionScorer.needsAmbientNote]);
  });

  test('中央を測っていれば、窓際・隣室側は中央との差で採点し、案内は出さない', () {
    final score = scorer.score(
      _inspection(ambient: _m(38), window: _m(48), neighbor: _m(44)),
    );
    expect(score.evaluatedSteps, 3);
    expect(score.notes, isEmpty);
    expect(score.components.firstWhere((c) => c.key == 'window').penalty, 20);
    expect(score.components.firstWhere((c) => c.key == 'neighbor').penalty, 12);
  });

  test('手叩きで残響が出なかったときは採点せず、測り直しを案内する', () {
    // 以前は「測定できず」で減点0(=最良)、測った項目にも数えていた。
    final score = scorer.score(
      _inspection(
        ambient: _m(38),
        clap: _knock(centroid: 900, t20: null, rt60: null),
      ),
    );
    expect(score.rt60, isNull);
    expect(score.components.map((c) => c.key), ['ambient']);
    expect(score.evaluatedSteps, 1);
    expect(score.takenSteps, 2);
    expect(score.notes, [InspectionScorer.clapRetryNote]);
  });

  test('ノックの判定できずは、これまでどおり5点減点で測った項目に数える', () {
    final score = scorer.score(
      _inspection(knock: _knock(centroid: 200, t20: 0.3, snr: 5)),
    );
    expect(score.components.single.penalty, 5);
    expect(score.evaluatedSteps, 1);
    expect(score.notes, isEmpty);
  });

  test('壁の判定の文は、遮音や壁の厚さを言い切らない目安の言い方にする', () {
    for (final w in [WallEstimate.heavy, WallEstimate.medium, WallEstimate.light]) {
      expect(w.label, endsWith('に近い音'));
      expect(w.description, contains('目安'));
      expect(w.description, contains('確かめたものではありません'));
      expect(w.description, isNot(contains('遮音性は高め')));
      expect(w.description, isNot(contains('通りやすい構造')));
    }
  });

  test('残響が長い部屋は響きで減点される', () {
    final score = scorer.score(
      _inspection(clap: _knock(centroid: 900, t20: 0.5, rt60: 1.5)),
    );
    expect(score.components.single.key, 'reverb');
    expect(score.components.single.penalty, 10);
  });
}
