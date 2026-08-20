import 'package:flutter/services.dart';

import '../models/measurement_result.dart';

/// ユーザーによるキャンセル、または電話着信・バックグラウンド移行・
/// マイクルート変更などの割り込みで計測が完了せずに終わったことを表す。
class MeasurementCancelledException implements Exception {}

/// iOSネイティブ側(SoundMeterPlugin)とのMethodChannel/EventChannelブリッジ。
class SoundMeterService {
  SoundMeterService()
    : _methodChannel = const MethodChannel(
        'jp.pairof.sound_shield/sound_meter',
      ),
      _eventChannel = const EventChannel(
        'jp.pairof.sound_shield/sound_meter/live',
      );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<double>? _liveDbStream;

  Future<bool> checkAndRequestPermission() async {
    final granted = await _methodChannel.invokeMethod<bool>(
      'checkAndRequestPermission',
    );
    return granted ?? false;
  }

  /// 計測中、約200ms間隔で流れてくる目安dB値(メーター表示用)。
  Stream<double> get liveDbStream {
    return _liveDbStream ??= _eventChannel.receiveBroadcastStream().map((
      event,
    ) {
      final map = Map<Object?, Object?>.from(event as Map);
      return (map['overallDb'] as num).toDouble();
    });
  }

  /// 計測を開始する。
  ///
  /// [duration]を指定すると、その時間が経過した時点で自動的に完了する。
  /// nullを渡すと「止めるまで測定」する時間無指定モードになり、
  /// [finishMeasurement]または[cancelMeasurement]が呼ばれるまで測定を続ける。
  ///
  /// 権限未許可・組み込みマイク以外への切替・エンジン起動失敗などは
  /// [PlatformException] として投げられる。ユーザーによるキャンセルや
  /// 割り込み(電話着信・バックグラウンド移行等)による中断は
  /// [MeasurementCancelledException] を投げる。
  Future<MeasurementResult> startMeasurement(Duration? duration) async {
    final map = await _methodChannel.invokeMapMethod<String, Object?>(
      'startMeasurement',
      {'durationSeconds': duration?.inSeconds},
    );
    if (map == null || map['cancelled'] == true) {
      throw MeasurementCancelledException();
    }
    return MeasurementResult.fromMap(map);
  }

  /// 時間無指定モードの計測を、ここまでの結果を保持したまま終える。
  /// [startMeasurement]が返すFutureがこの呼び出しを受けて解決する。
  Future<void> finishMeasurement() {
    return _methodChannel.invokeMethod('finishMeasurement');
  }

  /// 計測を破棄して終える。[startMeasurement]は[MeasurementCancelledException]を投げる。
  Future<void> cancelMeasurement() {
    return _methodChannel.invokeMethod('cancelMeasurement');
  }
}
