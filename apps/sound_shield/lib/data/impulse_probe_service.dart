import 'package:flutter/services.dart';

import '../models/impulse_result.dart';

/// 衝撃音が捕まらないままタイムアウトした。
class NoImpulseException implements Exception {}

/// ユーザー操作でキャンセルされた。
class ImpulseCancelledException implements Exception {}

/// ネイティブ側 ImpulseProbePlugin とのブリッジ。
class ImpulseProbeService {
  ImpulseProbeService([MethodChannel? channel])
    : _channel =
          channel ?? const MethodChannel('jp.pairof.sound_shield/impulse_probe');

  final MethodChannel _channel;

  /// 衝撃音を1発待って解析する。[timeout] 以内に来なければ [NoImpulseException]。
  Future<ImpulseResult> capture({
    Duration timeout = const Duration(seconds: 15),
    double onsetThresholdDb = 12,
  }) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('capture', {
        'timeoutSeconds': timeout.inMilliseconds / 1000,
        'onsetThresholdDb': onsetThresholdDb,
      });
      if (map == null) throw NoImpulseException();
      return ImpulseResult.fromMap(map);
    } on PlatformException catch (e) {
      if (e.code == 'no_impulse') throw NoImpulseException();
      if (e.code == 'cancelled') throw ImpulseCancelledException();
      rethrow;
    }
  }

  Future<void> cancel() => _channel.invokeMethod('cancel');
}
