import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/logic/time_series_downsampler.dart';
import 'package:sound_shield/models/time_series_point.dart';

void main() {
  group('downsampleForLine', () {
    test('点数がmaxPoints以下ならそのまま返す', () {
      final series = List.generate(
        50,
        (i) => TimeSeriesPoint(t: i.toDouble(), db: 50),
      );

      final result = downsampleForLine(series, maxPoints: 180);

      expect(result, same(series));
    });

    test('点数が多い場合はmaxPoints程度に間引く', () {
      final series = List.generate(
        3600,
        (i) => TimeSeriesPoint(t: i * 0.5, db: 40 + (i % 10)),
      );

      final result = downsampleForLine(series, maxPoints: 180);

      expect(result.length, lessThanOrEqualTo(180));
      // 先頭・末尾の時刻はおおよそ元データの範囲に収まる。
      expect(result.first.t, closeTo(series.first.t, 5));
      expect(result.last.t, closeTo(series.last.t, 5));
    });
  });

  group('axisTicks', () {
    test('短い計測(15秒)では4〜5本程度の目盛りになる', () {
      final ticks = axisTicks(15);

      expect(ticks.first, 0);
      expect(ticks.last, lessThanOrEqualTo(15));
      expect(ticks.length, inInclusiveRange(3, 6));
    });

    test('長い計測(1時間)でも目盛り本数が破綻しない', () {
      final ticks = axisTicks(3600);

      expect(ticks.length, inInclusiveRange(3, 10));
      expect(ticks.last, lessThanOrEqualTo(3600));
    });
  });

  group('formatAxisLabel', () {
    test('90秒未満は秒表記', () {
      expect(formatAxisLabel(30), '30s');
    });

    test('90秒以上は分表記', () {
      expect(formatAxisLabel(600), '10分');
    });
  });
}
