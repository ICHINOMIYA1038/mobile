import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sound_shield/data/sound_meter_service.dart';
import 'package:sound_shield/models/band_level.dart';
import 'package:sound_shield/models/detected_sound.dart';
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
/// 計測画面(02_measuring)・結果画面(03〜05)は、実際にマイクへアクセスすると
/// シミュレータでは音声入力が無く不安定なため、SoundMeterServiceが使う
/// MethodChannel/EventChannelをこのテスト内でモックし、固定のダミー計測結果を
/// 返すことで画面遷移だけは実際の操作(ボタンタップ)で再現している。
const _methodChannel = MethodChannel('jp.pairof.sound_shield/sound_meter');
const _eventChannel = EventChannel('jp.pairof.sound_shield/sound_meter/live');

final _dummyResult = MeasurementResult(
  durationSeconds: 15,
  overallLeqDb: 62,
  overallPeakDb: 78,
  overallMinDb: 41,
  bands: const [
    BandLevel(centerHz: 31.5, leqDb: 38, peakDb: 45, minDb: 30),
    BandLevel(centerHz: 63, leqDb: 42, peakDb: 50, minDb: 33),
    BandLevel(centerHz: 125, leqDb: 48, peakDb: 58, minDb: 36),
    BandLevel(centerHz: 250, leqDb: 55, peakDb: 66, minDb: 40),
    BandLevel(centerHz: 500, leqDb: 60, peakDb: 74, minDb: 42),
    BandLevel(centerHz: 1000, leqDb: 62, peakDb: 78, minDb: 41),
    BandLevel(centerHz: 2000, leqDb: 57, peakDb: 70, minDb: 39),
    BandLevel(centerHz: 4000, leqDb: 50, peakDb: 62, minDb: 34),
    BandLevel(centerHz: 8000, leqDb: 44, peakDb: 55, minDb: 30),
    BandLevel(centerHz: 16000, leqDb: 36, peakDb: 46, minDb: 26),
  ],
  soundLabels: const [
    DetectedSound(
      identifier: 'traffic_vehicle',
      activeShare: 0.62,
      avgConfidence: 0.81,
    ),
    DetectedSound(
      identifier: 'speech',
      activeShare: 0.18,
      avgConfidence: 0.55,
    ),
  ],
  timeSeries: const [
    TimeSeriesPoint(t: 0, db: 46),
    TimeSeriesPoint(t: 1, db: 48),
    TimeSeriesPoint(t: 2, db: 58),
    TimeSeriesPoint(t: 3, db: 66),
    TimeSeriesPoint(t: 4, db: 72),
    TimeSeriesPoint(t: 5, db: 68),
    TimeSeriesPoint(t: 6, db: 60),
    TimeSeriesPoint(t: 7, db: 55),
    TimeSeriesPoint(t: 8, db: 52),
    TimeSeriesPoint(t: 9, db: 50),
    TimeSeriesPoint(t: 10, db: 62),
    TimeSeriesPoint(t: 11, db: 64),
    TimeSeriesPoint(t: 12, db: 58),
    TimeSeriesPoint(t: 13, db: 49),
    TimeSeriesPoint(t: 14, db: 44),
  ],
  soundTimeline: const [
    SoundSegment(
      startSeconds: 2,
      endSeconds: 9,
      identifier: 'traffic_vehicle',
      confidence: 0.8,
    ),
    SoundSegment(
      startSeconds: 10,
      endSeconds: 13,
      identifier: 'speech',
      confidence: 0.6,
    ),
  ],
);

Map<String, Object?> _dummyResultMap() {
  return {
    'durationSeconds': _dummyResult.durationSeconds,
    'overallLeqDb': _dummyResult.overallLeqDb,
    'overallPeakDb': _dummyResult.overallPeakDb,
    'overallMinDb': _dummyResult.overallMinDb,
    'bands': _dummyResult.bands
        .map(
          (b) => {
            'centerHz': b.centerHz,
            'leqDb': b.leqDb,
            'peakDb': b.peakDb,
            'minDb': b.minDb,
          },
        )
        .toList(),
    'soundLabels': _dummyResult.soundLabels
        .map(
          (s) => {
            'identifier': s.identifier,
            'activeShare': s.activeShare,
            'avgConfidence': s.avgConfidence,
          },
        )
        .toList(),
    'timeSeries': _dummyResult.timeSeries
        .map((p) => {'t': p.t, 'db': p.db})
        .toList(),
    'soundTimeline': _dummyResult.soundTimeline
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

    // マイク権限は常に許可済み、liveDbStreamは固定値を流す。
    messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      switch (call.method) {
        case 'checkAndRequestPermission':
          return true;
        case 'startMeasurement':
          // 02_measuringのシャッターが間に合うよう少し待ってから結果を返す。
          await Future<void>.delayed(const Duration(milliseconds: 800));
          return _dummyResultMap();
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

    // 1枚目: ホーム画面(ゲージと計測方法・時間の選択)。
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: HomeScreen(soundMeterService: SoundMeterService()),
      ),
    );
    await tester.pumpAndSettle();
    await shoot(tester, '01_home');

    // 「計測を開始」→ 計測中画面へ。startMeasurementの応答を遅らせているので、
    // pumpAndSettleは使わずゲージが動いている状態を撮る。
    await tester.tap(find.text('計測を開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 2枚目: 計測中画面(ゲージが振れている状態)。
    await shoot(tester, '02_measuring');

    // startMeasurementの応答を待って結果画面へ自動遷移。
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 3枚目: 結果画面(Leq/最小/ピーク、ステータス、周波数帯・時系列グラフ)。
    await shoot(tester, '03_result');

    // 「対策を見る」は結果画面のListView末尾にあり画面外だとまだビルドされて
    // いないため、タップ前にスクロールして表示させる。
    await tester.scrollUntilVisible(
      find.text('対策を見る'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('対策を見る'));
    await tester.pumpAndSettle();

    // 4枚目: 対策画面(検出音の内訳と改善提案)。
    await shoot(tester, '04_suggestions');

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 結果画面のListViewは「対策を見る」までスクロールした位置のまま戻って
    // くるため、画面上部のステータスバッジ(infoアイコン)が画面外にある。
    // scrollUntilVisibleのdeltaが小さいとAppBar直下で「見えた」と誤判定して
    // 実際にはAppBarをタップしてしまうため、大きくドラッグして確実に
    // 先頭まで戻してからタップする。
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();

    // ステータスバッジ→ 騒音スケール画面へ。
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // 5枚目: 騒音スケール画面(環境省基準の3段階説明)。
    await shoot(tester, '05_noise_scale');
  });
}
