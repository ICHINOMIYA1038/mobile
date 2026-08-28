import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tomoshibi/main.dart';

import 'scene_urls.g.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 実行すると screenshots/ に書き出される。
///
/// 撮影方法は他アプリ (sound_shield 等) と同じで、シミュレータのtmpディレクトリに
/// マーカーファイルを置き、tool/screenshots.sh 側の常駐プロセスがそのタイミングで
/// `xcrun simctl io screenshot` により実画面を撮る方式。
///
/// このアプリ固有の事情:
///
/// - 画面の中身はWebView (Web版TOMOSHIBI小屋) なので、WidgetTesterから器具を
///   並べたり視点を切り替えたりはできない。代わりにWeb側の `#scene=<base64>`
///   共有URL (tomoshibi/src/io/sceneIO.ts) を使い、器具・役者・カメラ視点・客電を
///   すべて含んだシーンをURLとして流し込む。URLは tool/build_scene_urls.py が
///   組み立て、scene_urls.g.dart として吐き出す。
/// - WebGLの描画完了はFlutter側から観測できないため、pumpAndSettleではなく
///   固定時間ポンプし続けて待つ。ローディングのインジケータが回り続けるので
///   pumpAndSettleはそもそも収束しない。
/// - ATT許諾ダイアログはOSのアラートでWidgetTesterから閉じられないため、
///   requestTracking: false でリクエスト自体を止める。
/// - iPadではビューポート幅が768pxを超えるため、Web側がデスクトップ扱いになり
///   オブジェクトパネルが画面右に常時ドッキングされる (settings.panelOpen は
///   モバイルのボトムシート専用で、こちらには効かない)。iPadのスクリーンショットに
///   パネルが写るのは仕様どおり。横向きで撮れば3Dを広く取れるが、integration_test
///   からの SystemChrome.setPreferredOrientations ではシミュレータは回転しない
///   (2026-08-28に確認)。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final deadline = DateTime.now().add(duration);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (!done.existsSync()) {
      fail('スクリーンショット $name が撮られませんでした。'
          'tool/screenshots.sh 経由で実行していますか?');
    }
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    for (final spec in shotSpecs) {
      // 次のシーンを作る前に、前のWebViewを完全に破棄させる。
      // WebGLコンテキストとボリュメトリックのレンダーターゲットは重く、
      // 破棄を待たずに作り直し続けるとシミュレータのメモリを使い切って
      // アプリごと落ちる (2026-08-28に4枚目で実際に落ちた)。
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFor(tester, const Duration(seconds: 3));

      // ValueKeyを変えることでWebViewごと作り直させ、新しいURLを最初から読ませる。
      // (ハッシュだけ変えてもWeb側の tryLoadFromHash は初回マウント時にしか
      //  走らないため、シーンが切り替わらない。)
      await tester.pumpWidget(
        TomoshibiApp(
          key: ValueKey(spec.name),
          startUrl: spec.url,
          requestTracking: false,
        ),
      );
      // ページ読込 + Three.jsのシーン構築 + シェーダのコンパイルを待つ。
      await pumpFor(tester, const Duration(seconds: 25));
      await shoot(tester, spec.name);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
