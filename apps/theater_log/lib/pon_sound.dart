import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// スタンプの音。再生は iOS 側（AppDelegate）で行い、消音スイッチに従う
class PonSound {
  static const _channel = MethodChannel('gekipon/sound');

  static Future<void> prepare() async {
    try {
      final data = await rootBundle.load('assets/sounds/pon.wav');
      await _channel.invokeMethod<void>('prepare', data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } on MissingPluginException {
      // iOS 以外とテストでは音を鳴らさない
    } catch (e) {
      debugPrint('PonSound.prepare: $e');
    }
  }

  static Future<void> play() async {
    try {
      await _channel.invokeMethod<void>('play');
    } on MissingPluginException {
      // iOS 以外とテストでは音を鳴らさない
    } catch (e) {
      debugPrint('PonSound.play: $e');
    }
  }
}
