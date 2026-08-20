import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/data/sound_meter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('jp.pairof.sound_shield/sound_meter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('正常な結果はMeasurementResultとして返る', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'startMeasurement');
      expect(call.arguments, {'durationSeconds': 15});
      return {
        'durationSeconds': 15,
        'overallLeqDb': 62.3,
        'overallPeakDb': 78.1,
        'overallMinDb': 41.5,
        'bands': [
          {'centerHz': 63.0, 'leqDb': 58.1, 'peakDb': 70.2, 'minDb': 45.0},
        ],
        'soundLabels': [
          {
            'identifier': 'vehicle_engine',
            'activeShare': 0.42,
            'avgConfidence': 0.71,
          },
        ],
        'timeSeries': [
          {'t': 0.0, 'db': 50.0},
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
      };
    });

    final service = SoundMeterService();
    final result = await service.startMeasurement(const Duration(seconds: 15));

    expect(result.overallLeqDb, 62.3);
    expect(result.overallMinDb, 41.5);
    expect(result.bands.single.centerHz, 63.0);
    expect(result.bands.single.minDb, 45.0);
    expect(result.soundLabels.single.identifier, 'vehicle_engine');
    expect(result.timeSeries, hasLength(2));
    expect(result.soundTimeline.single.identifier, 'vehicle_engine');
  });

  test('ネイティブ側がcancelledを返したらMeasurementCancelledExceptionを投げる', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      return {'cancelled': true};
    });

    final service = SoundMeterService();

    expect(
      () => service.startMeasurement(const Duration(seconds: 15)),
      throwsA(isA<MeasurementCancelledException>()),
    );
  });

  test('durationがnullなら止めるまで測定モードとしてdurationSeconds:nullを送る', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'startMeasurement');
      expect(call.arguments, {'durationSeconds': null});
      return {
        'durationSeconds': 320,
        'overallLeqDb': 55.0,
        'overallPeakDb': 70.0,
        'overallMinDb': 38.0,
        'bands': [],
        'soundLabels': [],
      };
    });

    final service = SoundMeterService();
    final result = await service.startMeasurement(null);

    expect(result.durationSeconds, 320);
  });

  test('finishMeasurementはネイティブ側にfinishMeasurementを呼ぶ', () async {
    var calledMethod = '';
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calledMethod = call.method;
      return null;
    });

    final service = SoundMeterService();
    await service.finishMeasurement();

    expect(calledMethod, 'finishMeasurement');
  });
}
