// ストア用スクリーンショット + 動作確認。tool/screenshots.sh から実行する。
// 撮影は tool/screenshots.sh 側が `xcrun simctl io screenshot` で行い、ここでは
// シミュレータの tmp にマーカーを置くだけ（takeScreenshot は iOS+Impeller で使えない）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/main.dart' as app;

String _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data ?? '')
    .where((t) => t.isNotEmpty)
    .take(20)
    .join(' | ');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 400));
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

  /// 条件が満たされるまで 1秒ずつ pump する（ストリーム中はアニメーションが止まらないので pumpAndSettle 不可）。
  Future<bool> waitFor(WidgetTester tester, bool Function() cond, {int seconds = 60}) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    var ticks = 0;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 500));
      final e = tester.takeException();
      if (e != null) { debugPrint('APP EXCEPTION: $e'); File('${Directory.systemTemp.path}/diag.txt').writeAsStringSync('EXC: $e\n', mode: FileMode.append); }
      if (cond()) return true;
      if (++ticks % 20 == 0) debugPrint('waiting… texts: ${_visibleTexts()}');
    }
    debugPrint('TIMEOUT texts: ${_visibleTexts()}'); File('${Directory.systemTemp.path}/diag.txt').writeAsStringSync('TIMEOUT: ${_visibleTexts()}\n', mode: FileMode.append);
    return false;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: '"$text" が見つからない');
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    // Crashlytics が FlutterError.onError を差し替えるので、テスト終了時に元へ戻す
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    final diag = File('${Directory.systemTemp.path}/diag.txt');
    void log(String m) => diag.writeAsStringSync('$m\n', mode: FileMode.append);
    log('start');
    await app.main();
    // Crashlytics の onError だとテスト側に例外が届かず原因が隠れるので、テスト中は戻す
    FlutterError.onError = originalOnError;
    log('main done');
    // /v1/me が返るまで
    final ready = await waitFor(tester, () => find.text('第1章を無料で始める').evaluate().isNotEmpty || find.text('カリキュラム').evaluate().isNotEmpty, seconds: 30);
    expect(ready, isTrue, reason: 'APIに接続できない');

    if (find.text('第1章を無料で始める').evaluate().isNotEmpty) {
      await shoot(tester, '00_onboarding');
      await tapText(tester, '第1章を無料で始める');
      await waitFor(tester, () => find.text('カリキュラム').evaluate().isNotEmpty, seconds: 20);
    }
    await shoot(tester, '02_home');

    // 第1章へ。CTA のラベルは初回/継続で変わるので FilledButton の先頭を押す
    final cta = find.byType(FilledButton).first;
    await tester.tap(cta);
    await tester.pump(const Duration(seconds: 1));

    // 最初の返答とカードが出るまで
    // 未回答のカード(○×ボタンが出ている)が出るまで
    final gotCard = await waitFor(tester, () => find.text('○ 正しい').evaluate().isNotEmpty, seconds: 90);
    expect(gotCard, isTrue, reason: 'カードが出ない');
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '01_chat_question');

    // ○ を押して採点 → 返答
    await tapText(tester, '○ 正しい');
    final graded = await waitFor(tester, () => find.textContaining('と回答').evaluate().isNotEmpty, seconds: 60);
    expect(graded, isTrue, reason: '採点結果が出ない');
    await waitFor(tester, () => find.text('○ 正しい').evaluate().isNotEmpty, seconds: 60);
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '03_chat_graded');

    // 言葉で答える
    final field = find.byType(TextField);
    if (field.evaluate().isNotEmpty) {
      await tester.enterText(field, '免許は事務所の場所で決まるんですよね？');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await waitFor(tester, () => find.textContaining('免許は事務所').evaluate().isNotEmpty, seconds: 10);
      await tester.pump(const Duration(seconds: 6));
      await shoot(tester, '04_chat_talk');
    }

    // 戻って進捗・設定・プラン
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('進捗').last);
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '05_progress');
    await tester.tap(find.text('学ぶ').last);
    await tester.pump(const Duration(seconds: 1));
    // 第2章（ロック）→ プラン画面
    final ch2 = find.textContaining('第2章');
    if (ch2.evaluate().isNotEmpty) {
      await tester.tap(ch2.first);
      await tester.pump(const Duration(seconds: 2));
      await shoot(tester, '06_paywall');
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('設定').last);
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '07_settings');
  });
}
