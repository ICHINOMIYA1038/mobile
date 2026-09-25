// ストア用スクリーンショット + 通しの動作確認。tool/screenshots.sh から実行する。
// 撮影は tool/screenshots.sh 側が `xcrun simctl io screenshot` で行い、ここでは
// シミュレータの tmp にマーカーを置くだけ（takeScreenshot は iOS+Impeller で使えない）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/main.dart' as app;
import 'package:takken_talk/widgets/figure_card.dart';

String _texts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data ?? '')
    .where((t) => t.isNotEmpty)
    .take(24)
    .join(' | ');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final diag = File('${Directory.systemTemp.path}/diag.txt');
  void log(String m) => diag.writeAsStringSync('$m\n', mode: FileMode.append);

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 500));
    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    log('shot $name');
  }

  Future<bool> waitFor(WidgetTester tester, bool Function() cond, {int seconds = 60}) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 500));
      final e = tester.takeException();
      if (e != null) log('EXC: $e');
      if (cond()) return true;
    }
    log('TIMEOUT: ${_texts()}');
    return false;
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    log('start');
    await app.main();
    FlutterError.onError = originalOnError;

    expect(
      await waitFor(tester, () => find.text('第1章を無料で始める').evaluate().isNotEmpty || find.text('カリキュラム').evaluate().isNotEmpty, seconds: 30),
      isTrue,
      reason: 'APIに接続できない',
    );

    // 01 はじめの画面（何を学ぶかが1枚で分かる）
    if (find.text('第1章を無料で始める').evaluate().isNotEmpty) {
      await shoot(tester, '01_onboarding');
      await tester.tap(find.text('第1章を無料で始める'));
      await waitFor(tester, () => find.text('カリキュラム').evaluate().isNotEmpty, seconds: 20);
    }

    // 02 ホーム（科目ごとに束ねたカリキュラム）
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '02_home');

    // 章に入る
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump(const Duration(seconds: 1));

    // 03 会話の入口（章の地図が開いた状態）
    expect(await waitFor(tester, () => find.textContaining('この章のテーマ').evaluate().isNotEmpty, seconds: 20), isTrue, reason: '章の地図が出ない');
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '03_chapter_map');

    // 最初の返答が終わるまで待つ（返答中はクイック返信が消える）
    expect(await waitFor(tester, () => find.text('次の問題').evaluate().isNotEmpty, seconds: 150), isTrue, reason: '最初の返答が終わらない');
    await tester.pump(const Duration(seconds: 1));

    // 出題を頼む（最初の一言は会話で問いかけるだけで、カードは出ない作り）
    await tester.tap(find.text('次の問題').first);
    expect(await waitFor(tester, () => find.text('○ 正しい').evaluate().isNotEmpty, seconds: 150), isTrue, reason: 'カードが出ない');
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '04_chat_question');

    // ○ を押して採点
    await tester.tap(find.text('○ 正しい').first);
    await waitFor(tester, () => find.textContaining('と回答').evaluate().isNotEmpty, seconds: 120);
    await waitFor(tester, () => find.text('次の問題').evaluate().isNotEmpty || find.text('ヒントちょうだい').evaluate().isNotEmpty, seconds: 120);
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '05_chat_graded');

    // 図解を引き出す
    final field = find.byType(TextField);
    if (field.evaluate().isNotEmpty) {
      await tester.enterText(field, '営業保証金と保証協会の金額がごちゃごちゃです。整理して');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      final gotFigure = await waitFor(tester, () => find.byType(FigureCard).evaluate().isNotEmpty, seconds: 180);
      log('figure shown: $gotFigure');
      await waitFor(tester, () => find.text('次の問題').evaluate().isNotEmpty || find.text('ヒントちょうだい').evaluate().isNotEmpty, seconds: 120);
      await tester.pump(const Duration(seconds: 2));
      await shoot(tester, '06_chat_figure');
    }

    // 章の図解一覧
    await tester.tap(find.byIcon(Icons.image_outlined).first);
    await waitFor(tester, () => find.textContaining('の図解').evaluate().isNotEmpty, seconds: 20);
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '07_figures');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    // 学習の地図
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('地図').last);
    await waitFor(tester, () => find.text('学習の地図').evaluate().isNotEmpty, seconds: 20);
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '08_map');

    // 章を開いて小テーマまで見せる
    final ch1 = find.textContaining('免許・宅建士・保証制度');
    if (ch1.evaluate().isNotEmpty) {
      await tester.tap(ch1.first);
      await tester.pump(const Duration(seconds: 2));
      await shoot(tester, '09_map_topics');
    }
    log('done');
  });
}
