/// 楽譜画像 → ドレミ認識エンジンの抽象。
///
/// 本番は [NativeDoremiEngine]（iOS: Core ML の五線UNet＋単旋律CRNNをネイティブで実行）。
/// 開発・テスト用に [MockDoremiEngine]。UI 層はこの抽象だけに依存する。
library;

import 'dart:async';

import '../models/score.dart';

/// 認識中の進捗段階。UI のプログレス表示に使う。
enum RecognizePhase { preparing, detectingStaves, recognizing, rendering, done }

class RecognizeProgress {
  final RecognizePhase phase;
  final double fraction; // 0.0〜1.0
  const RecognizeProgress(this.phase, this.fraction);
}

abstract class DoremiEngine {
  /// 画像ファイルを認識してドレミ譜を返す。
  /// [onProgress] は任意。長時間処理の途中経過を通知する。
  Future<RecognizedScore> recognize(
    String imagePath, {
    void Function(RecognizeProgress)? onProgress,
  });

  /// エンジンが利用可能か（モデルのロード可否など）。
  Future<bool> get isAvailable;
}

/// 認識に失敗したとき投げる例外（UI で握ってメッセージ表示）。
class RecognizeException implements Exception {
  final String message;
  const RecognizeException(this.message);
  @override
  String toString() => 'RecognizeException: $message';
}
