import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/detected_sound.dart';
import 'package:sound_shield/models/measurement_result.dart';
import 'package:sound_shield/models/time_series_point.dart';
import 'package:sound_shield/ui/screens/result_screen.dart';
import 'package:sound_shield/ui/widgets/noise_scale_chart.dart';

MeasurementResult _buildResult({
  required double overallLeqDb,
  List<BandLevel> bands = const [],
  List<DetectedSound> soundLabels = const [],
}) {
  return MeasurementResult(
    durationSeconds: 15,
    overallLeqDb: overallLeqDb,
    overallPeakDb: overallLeqDb + 16,
    overallMinDb: overallLeqDb - 20,
    bands: bands,
    soundLabels: soundLabels,
    timeSeries: const [
      TimeSeriesPoint(t: 0, db: 40),
      TimeSeriesPoint(t: 7.5, db: 70),
      TimeSeriesPoint(t: 15, db: 45),
    ],
  );
}

void main() {
  testWidgets('総合レベルとグラフが表示され、対策CTAから対策画面へ遷移できる', (tester) async {
    // ListViewの全項目をスクロールなしで検証できるよう、十分な高さを確保する。
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = _buildResult(
      overallLeqDb: 52,
      bands: const [
        BandLevel(centerHz: 63, leqDb: 55, peakDb: 60, minDb: 48),
        BandLevel(centerHz: 4000, leqDb: 40, peakDb: 45, minDb: 34),
      ],
      soundLabels: const [
        DetectedSound(
          identifier: 'vehicle_engine',
          activeShare: 0.42,
          avgConfidence: 0.71,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    expect(find.text('52'), findsNWidgets(2)); // ヒーロー数値 + 「平均」統計
    expect(find.text('普通の生活音'), findsOneWidget);
    expect(find.text('対策を見る'), findsOneWidget);
    expect(find.textContaining('件の提案'), findsOneWidget);

    await tester.tap(find.text('対策を見る'));
    await tester.pumpAndSettle();

    expect(find.text('検出された音'), findsOneWidget);
    expect(find.text('車の音'), findsOneWidget);
    expect(find.text('ホームに戻る'), findsOneWidget);
  });

  testWidgets(
    '静かな計測では状態バッジが「静かな環境」になり、対策の代わりに不要である旨を表示する',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = _buildResult(overallLeqDb: 25);

      await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

      expect(find.text('静かな環境'), findsOneWidget);
      expect(find.text('静かな環境でした'), findsOneWidget);
      expect(find.text('対策を見る'), findsNothing);
    },
  );

  testWidgets('うるさい計測では状態バッジが「うるさい環境」になる', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = _buildResult(overallLeqDb: 82);

    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    expect(find.text('うるさい環境'), findsOneWidget);
  });

  testWidgets('状態バッジをタップすると騒音レベルの目安画面に遷移する', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = _buildResult(overallLeqDb: 52);

    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    await tester.tap(find.text('普通の生活音'));
    await tester.pumpAndSettle();

    expect(find.text('騒音レベルの目安'), findsOneWidget);
    expect(find.byType(NoiseScaleChart), findsOneWidget);
  });
}
