/// ネイティブ(iOS Core ML)実装。MethodChannel 経由で Swift 側のパイプラインを呼ぶ。
///
/// Swift 側 (`DoremiPlugin.swift`) が以下を実行する:
///   1. 五線UNet(staff.mlpackage) で五線ヒートマップ → 段検出 → 湾曲補正(dewarp)
///   2. 各段を単旋律CRNN(mono.mlpackage) で認識 (CTC greedy) → 音高・音価・x位置
///   3. 段ストリップ画像を一時ディレクトリに書き出し、結果JSONを返す
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../models/score.dart';
import 'doremi_engine.dart';

class NativeDoremiEngine implements DoremiEngine {
  static const MethodChannel _channel =
      MethodChannel('jp.pairof.doremi_scan/engine');
  static const EventChannel _progress =
      EventChannel('jp.pairof.doremi_scan/progress');

  @override
  Future<bool> get isAvailable async {
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<RecognizedScore> recognize(
    String imagePath, {
    void Function(RecognizeProgress)? onProgress,
  }) async {
    StreamSubscription<dynamic>? sub;
    if (onProgress != null) {
      sub = _progress.receiveBroadcastStream().listen((event) {
        final m = Map<String, dynamic>.from(event as Map);
        final phase = RecognizePhase.values.firstWhere(
          (p) => p.name == m['phase'],
          orElse: () => RecognizePhase.recognizing,
        );
        onProgress(RecognizeProgress(
            phase, (m['fraction'] as num?)?.toDouble() ?? 0));
      });
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'recognize',
        {'imagePath': imagePath},
      );
      if (res == null) {
        throw const RecognizeException('認識結果が取得できませんでした。');
      }
      return RecognizedScore.fromJson(Map<String, dynamic>.from(res));
    } on PlatformException catch (e) {
      throw RecognizeException(e.message ?? '認識中にエラーが発生しました。');
    } on MissingPluginException {
      throw const RecognizeException(
          'ネイティブ認識エンジンに接続できませんでした（チャンネル未登録）。アプリを再インストールしてください。');
    } finally {
      await sub?.cancel();
    }
  }
}
