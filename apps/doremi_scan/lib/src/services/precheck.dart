import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// 読み取り前の事前チェック。
/// 30秒待った末に「読めませんでした」を出さないために、
/// オンデバイスの五線検出(Core ML)で楽譜の大きさを先に確かめる。
class Precheck {
  static const MethodChannel _channel =
      MethodChannel('jp.pairof.doremi_scan/engine');

  /// 送信画像での推定五線間隔(px)。線間隔がこの値を下回ると読み落としが激増する。
  static const double minInterlinePx = 11.0;

  /// 画像内で最大の五線の間隔を、サーバーへ送る解像度(長辺3000px上限)換算で推定。
  /// 五線を検出できなければ null（チェック不能＝ブロックしない）。
  static Future<double?> interlinePx(String path) async {
    try {
      final raw = await File(path).readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;
      // 検出用に幅700へ縮小したグレースケールを作る
      const tw = 700;
      final small = img.copyResize(decoded, width: tw);
      final gray = Uint8List(small.width * small.height);
      var i = 0;
      for (var y = 0; y < small.height; y++) {
        for (var x = 0; x < small.width; x++) {
          final p = small.getPixel(x, y);
          gray[i++] = ((p.r + p.g + p.b) ~/ 3).toInt();
        }
      }
      final res = await _channel.invokeMethod<List<dynamic>>('detectStaves', {
        'gray': gray,
        'width': small.width,
        'height': small.height,
      });
      final bands = (res ?? const [])
          .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .where((b) => b.length >= 2)
          .toList();
      if (bands.isEmpty) return null;
      final maxBand =
          bands.map((b) => b[1] - b[0]).reduce((a, b) => a > b ? a : b);
      // 送信時の縦解像度（長辺3000pxキャップ後）
      final longest = max(decoded.width, decoded.height);
      final sendScale = longest > 3000 ? 3000 / longest : 1.0;
      final sendH = decoded.height * sendScale;
      return maxBand / 4 * sendH;
    } catch (_) {
      return null; // iOS以外・検出失敗はチェックなしで通す
    }
  }

  /// 小さすぎる画像のインデックス一覧（1始まりの枚数表記用に+1して返す）。
  static Future<List<int>> tooSmallPages(List<String> paths) async {
    final out = <int>[];
    for (var i = 0; i < paths.length; i++) {
      final il = await interlinePx(paths[i]);
      if (il != null && il < minInterlinePx) out.add(i + 1);
    }
    return out;
  }
}
