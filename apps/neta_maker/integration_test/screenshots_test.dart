import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neta_maker/main.dart';
import 'package:neta_maker/models/maker_result.dart';

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
/// 実画面をそのタイミングで撮る方式にしている（etude_generatorと同じ方式）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> diagnose(WidgetTester tester, MakerCategory category, String name) async {
    await tester.tap(find.text(category.title));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), name);
    await tester.pumpAndSettle();
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    // 1枚目: ホーム画面。3つの診断カードが並ぶ。
    await tester.pumpWidget(const NetaMakerApp());
    await tester.pumpAndSettle();
    await shoot(tester, '01_home');

    // 2枚目: 名前入力画面（二つ名メーカー）。
    await diagnose(tester, MakerCategory.futatsuna, 'たろう');
    await shoot(tester, '02_input');

    // 3枚目: 二つ名メーカーの結果画面。
    await tester.tap(find.textContaining('診断する'));
    await tester.pumpAndSettle();
    await shoot(tester, '03_result_futatsuna');

    // 4枚目: 前世メーカーの結果画面。
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    await diagnose(tester, MakerCategory.zensei, 'はなこ');
    await tester.tap(find.textContaining('診断する'));
    await tester.pumpAndSettle();
    await shoot(tester, '04_result_zensei');

    // 5枚目: 脳内メーカーの結果画面。
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    await diagnose(tester, MakerCategory.nounai, 'ゆうき');
    await tester.tap(find.textContaining('診断する'));
    await tester.pumpAndSettle();
    await shoot(tester, '05_result_nounai');
  });
}
