import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_shield/data/app_scope.dart';
import 'package:sound_shield/data/ar_noise_map_service.dart';
import 'package:sound_shield/data/impulse_probe_service.dart';
import 'package:sound_shield/data/calibration_repository.dart';
import 'package:sound_shield/data/inspection_repository.dart';
import 'package:sound_shield/data/sound_meter_service.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/countermeasure_record.dart';
import 'package:sound_shield/models/detected_sound.dart';
import 'package:sound_shield/models/impulse_result.dart';
import 'package:sound_shield/models/inspection.dart';
import 'package:sound_shield/models/measurement_result.dart';
import 'package:sound_shield/models/sound_segment.dart';
import 'package:sound_shield/models/time_series_point.dart';
import 'package:sound_shield/ui/screens/home_screen.dart';
import 'package:sound_shield/ui/theme.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 実行すると screenshots/ に書き出される。
///
/// 撮影方法について: 他アプリ(neta_gacha等)と同じ、シミュレータのtmpディレクトリに
/// マーカーファイルを置き、tool/screenshots.sh側の常駐プロセスが
/// `xcrun simctl io screenshot` で実画面をそのタイミングで撮る方式。
///
/// シミュレータではマイク入力・ARが使えないため、SoundMeterService の
/// MethodChannel をモックし、内見診断・対策記録は SharedPreferences に
/// ダミーデータを流し込んでから画面を開く。
const _methodChannel = MethodChannel('jp.pairof.sound_shield/sound_meter');
const _eventChannel = EventChannel('jp.pairof.sound_shield/sound_meter/live');

MeasurementResult _measurement({
  required double leq,
  required List<double> bands,
  List<DetectedSound> labels = const [],
}) {
  const centers = [31.5, 63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
  return MeasurementResult(
    durationSeconds: 15,
    overallLeqDb: leq,
    overallPeakDb: leq + 14,
    overallMinDb: leq - 18,
    bands: [
      for (var i = 0; i < bands.length; i++)
        BandLevel(
          centerHz: centers[i],
          leqDb: bands[i],
          peakDb: bands[i] + 10,
          minDb: bands[i] - 8,
        ),
    ],
    soundLabels: labels,
    timeSeries: [
      for (var t = 0; t <= 15; t++)
        TimeSeriesPoint(t: t.toDouble(), db: leq - 8 + 12 * ((t * 7) % 5) / 4),
    ],
    soundTimeline: const [
      SoundSegment(startSeconds: 2, endSeconds: 9, identifier: 'traffic_vehicle', confidence: 0.8),
      SoundSegment(startSeconds: 10, endSeconds: 13, identifier: 'speech', confidence: 0.6),
    ],
  );
}

final _traffic = [
  const DetectedSound(identifier: 'traffic_vehicle', activeShare: 0.62, avgConfidence: 0.81),
  const DetectedSound(identifier: 'speech', activeShare: 0.18, avgConfidence: 0.55),
];

final _meterResult = _measurement(
  leq: 62,
  bands: [38, 42, 48, 55, 60, 62, 57, 50, 44, 36],
  labels: _traffic,
);

Map<String, Object?> _meterResultMap() => {
  ..._meterResult.toJson(),
  'soundTimeline': _meterResult.soundTimeline
      .map(
        (s) => {
          'startSeconds': s.startSeconds,
          'endSeconds': s.endSeconds,
          'identifier': s.identifier,
          'confidence': s.confidence,
        },
      )
      .toList(),
};

ImpulseResult _impulse({required double centroid, required double t20, double? rt60}) {
  return ImpulseResult(
    peakDb: 82,
    floorDb: 44,
    snrDb: 38,
    t10: t20 / 2,
    t20: t20,
    rt60: rt60 ?? t20 * 3,
    spectralCentroidHz: centroid,
    lowShare: 0.5,
    highShare: 0.2,
    peakHz: centroid,
  );
}

/// 3物件分のダミー診断(スコアが散るように)。
List<Inspection> _inspections() {
  final now = DateTime(2026, 8, 28, 14);
  return [
    Inspection(
      id: 'a',
      name: 'サンライズ荻窪 302',
      createdAt: now,
      ambient: _measurement(leq: 41, bands: [30, 33, 36, 38, 40, 39, 36, 32, 28, 24]),
      window: _measurement(
        leq: 54,
        bands: [40, 44, 47, 50, 52, 51, 47, 42, 36, 30],
        labels: _traffic,
      ),
      knock: _impulse(centroid: 1650, t20: 0.19),
      clap: _impulse(centroid: 900, t20: 0.24, rt60: 0.7),
      neighbor: _measurement(leq: 43, bands: [31, 34, 37, 40, 42, 41, 38, 33, 28, 24]),
    ),
    Inspection(
      id: 'b',
      name: 'パークコート中野 805',
      createdAt: now.subtract(const Duration(days: 1)),
      ambient: _measurement(leq: 35, bands: [26, 28, 30, 32, 34, 33, 30, 26, 22, 20]),
      window: _measurement(leq: 37, bands: [28, 30, 32, 34, 36, 35, 32, 28, 24, 20]),
      knock: _impulse(centroid: 520, t20: 0.05),
      clap: _impulse(centroid: 900, t20: 0.15, rt60: 0.45),
      neighbor: _measurement(leq: 36, bands: [27, 29, 31, 33, 35, 34, 31, 27, 23, 20]),
    ),
    Inspection(
      id: 'c',
      name: 'メゾン高円寺 201',
      createdAt: now.subtract(const Duration(days: 2)),
      ambient: _measurement(leq: 48, bands: [36, 40, 43, 45, 47, 46, 42, 38, 32, 28]),
      window: _measurement(leq: 51, bands: [38, 42, 45, 48, 50, 49, 45, 40, 34, 30]),
      knock: _impulse(centroid: 1100, t20: 0.11),
      neighbor: _measurement(leq: 55, bands: [40, 44, 48, 52, 54, 53, 49, 44, 38, 32]),
    ),
  ];
}

List<CountermeasureRecord> _records() {
  final before = _measurement(
    leq: 58,
    bands: [34, 38, 44, 50, 55, 57, 54, 48, 42, 34],
    labels: const [
      DetectedSound(identifier: 'speech', activeShare: 0.55, avgConfidence: 0.7),
    ],
  );
  return [
    CountermeasureRecord(
      id: 'r1',
      measureId: 'curtain',
      measureName: '防音カーテン',
      createdAt: DateTime(2026, 8, 20),
      before: before,
      after: _measurement(leq: 54, bands: [34, 38, 44, 49, 53, 54, 50, 43, 36, 28]),
      predictedDeltaDb: 3.4,
      place: '寝室・窓側',
    ),
    CountermeasureRecord(
      id: 'r2',
      measureId: 'door_seal',
      measureName: 'ドアの隙間塞ぎ(戸当たりテープ+ドア下ストッパー)',
      createdAt: DateTime(2026, 8, 27),
      before: before,
      predictedDeltaDb: 2.1,
      place: '寝室・ドア側',
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();

    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      switch (call.method) {
        case 'checkAndRequestPermission':
          return true;
        case 'startMeasurement':
          await Future<void>.delayed(const Duration(milliseconds: 800));
          return _meterResultMap();
        case 'finishMeasurement':
        case 'cancelMeasurement':
          return null;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) => events.success({'overallDb': 63.0}),
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(_methodChannel, null);
      messenger.setMockStreamHandler(_eventChannel, null);
    });

    // ダミーの診断・記録を保存してから起動する。
    SharedPreferences.setMockInitialValues({});
    final repo = InspectionRepository();
    for (final i in _inspections().reversed) {
      await repo.saveInspection(i);
    }
    for (final r in _records().reversed) {
      await repo.saveRecord(r);
    }
    final services = AppServices(
      soundMeter: SoundMeterService(),
      impulseProbe: ImpulseProbeService(),
      arNoiseMap: ArNoiseMapService(),
      inspections: repo,
      calibration: CalibrationRepository(soundMeter: SoundMeterService()),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1枚目: 内見診断の結果(スコア・弱点・壁の推定)。
    await tester.tap(find.text('サンライズ荻窪 302'));
    await tester.pumpAndSettle();
    await shoot(tester, '01_inspection_result');

    // 2枚目: 対策シミュレーター(予測ΔdB・費用・効かない理由)。
    await tester.scrollUntilVisible(
      find.text('効く対策を予測する'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('効く対策を予測する'));
    await tester.pumpAndSettle();
    await shoot(tester, '02_simulator');

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 3枚目: 物件の比較。
    await tester.scrollUntilVisible(
      find.text('他の物件と比較'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('他の物件と比較'));
    await tester.pumpAndSettle();
    await shoot(tester, '03_compare');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4枚目: ホーム。
    await shoot(tester, '04_home');

    // 5枚目: 対策の効果検証(Before/After)。
    await tester.tap(find.text('対策の効果を検証'));
    await tester.pumpAndSettle();
    await shoot(tester, '05_before_after');

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 6枚目: 騒音計の結果(周波数帯・時間推移)。
    await tester.tap(find.text('騒音計'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('計測を開始'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await shoot(tester, '06_meter_result');
  });
}
