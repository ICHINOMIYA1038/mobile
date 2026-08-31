import 'package:flutter/services.dart';

import '../models/ar_noise_sample.dart';

/// ARマップ計測中のライブ値。
class ArLiveUpdate {
  const ArLiveUpdate({
    required this.trackingNormal,
    this.interrupted = false,
    required this.db,
    required this.count,
    required this.minDb,
    required this.maxDb,
  });

  final bool trackingNormal;

  /// 電話着信などで音声入力が止まった。計測を終えるしかない。
  final bool interrupted;
  final double db;
  final int count;
  final double minDb;
  final double maxDb;
}

/// ネイティブ側 ArNoiseMapPlugin とのブリッジ。PlatformView 本体は
/// `ArNoiseMapService.viewType` で UiKitView から作る。
class ArNoiseMapService {
  ArNoiseMapService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method =
          methodChannel ??
          const MethodChannel('jp.pairof.sound_shield/ar_noise_map'),
      _event =
          eventChannel ??
          const EventChannel('jp.pairof.sound_shield/ar_noise_map/live');

  static const viewType = 'jp.pairof.sound_shield/ar_noise_map_view';

  final MethodChannel _method;
  final EventChannel _event;
  Stream<ArLiveUpdate>? _live;

  Future<bool> isSupported() async =>
      (await _method.invokeMethod<bool>('isSupported')) ?? false;

  Future<void> start() => _method.invokeMethod('start');

  Future<void> setSurface(ArSurface surface) =>
      _method.invokeMethod('setTag', {'tag': surface.name});

  Future<List<ArNoiseSample>> stop() async {
    final map = await _method.invokeMapMethod<String, Object?>('stop');
    final raw = (map?['samples'] as List?) ?? const [];
    return raw
        .map((e) => ArNoiseSample.fromMap(Map<Object?, Object?>.from(e as Map)))
        .toList();
  }

  Stream<ArLiveUpdate> get liveStream {
    return _live ??= _event.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      final db = (map['db'] as num?)?.toDouble() ?? 0;
      return ArLiveUpdate(
        trackingNormal: map['tracking'] == 'normal',
        interrupted: map['tracking'] == 'interrupted',
        db: db,
        count: (map['count'] as num?)?.toInt() ?? 0,
        minDb: (map['minDb'] as num?)?.toDouble() ?? db,
        maxDb: (map['maxDb'] as num?)?.toDouble() ?? db,
      );
    });
  }
}
