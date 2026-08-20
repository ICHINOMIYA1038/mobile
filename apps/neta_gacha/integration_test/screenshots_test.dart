import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neta_gacha/data/ad_service.dart';
import 'package:neta_gacha/main.dart';
import 'package:neta_gacha/ui/widgets/gacha_knob_button.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 実行すると screenshots/ に書き出される。
///
/// 撮影方法について: `binding.takeScreenshot()` は使わない。
/// iOS + Impeller ではこの API が実際の描画内容を無視して単色の背景しか返さない
/// 不具合があるうえ、`flutter drive` の拡張ドライバは screenshot をテスト完了後に
/// まとめて回収する仕組みのため、各ショットのタイミングと画面遷移が一致しない
/// （全ショットが最後の画面になる）。そこで、シミュレータの tmp
/// ディレクトリ（ホストからも同じパスで見える）にマーカーファイルを置き、
/// `tool/screenshots.sh` 側の常駐プロセスが `xcrun simctl io screenshot` で
/// 実画面をそのタイミングで撮る方式にしている（takken_simple/neta_makerと同じ方式）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // ストア用スクリーンショットに実機/テストの広告(「Test mode」表示など)を
  // 写り込ませないため、AdBannerSlotが常に高さ0になるようにする。
  AdService.disableForTests = true;

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
    // 1枚目: ホーム画面。ガチャマシンのイラストとシチュエーションタイル一覧。
    await tester.pumpWidget(const NetaGachaApp());
    await tester.pumpAndSettle();
    await shoot(tester, '01_home');

    // 「オープニング」を選んでルーレット画面へ。
    await tester.tap(find.text('オープニング'));
    await tester.pumpAndSettle();

    // 2枚目: ガチャを引く前(ノブが主役の状態)。
    await shoot(tester, '02_roulette');

    // ノブをひねってお題を引く。
    await tester.tap(find.byType(GachaKnobButton));
    await tester.pump(const Duration(milliseconds: 600)); // ノブの回転アニメ分。
    await tester.pumpAndSettle();

    // 3枚目: お題カード結果表示(手書き風フォント)。
    await shoot(tester, '03_result');

    // お気に入りに登録してからお気に入り画面へ。
    await tester.tap(find.byIcon(Icons.star_border_rounded));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_rounded));
    await tester.pumpAndSettle();

    // 4枚目: お気に入り画面。
    await shoot(tester, '04_favorites');

    await tester.pageBack();
    await tester.pumpAndSettle();

    // カスタムお題画面へ。サンプルを1件追加してから撮る。
    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '今日ハマってるゲームの話',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();

    // 5枚目: カスタムお題画面(自分で追加したお題つき)。
    await shoot(tester, '05_custom');
  });
}
