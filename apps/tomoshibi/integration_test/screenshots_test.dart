import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tomoshibi/main.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    if (!done.existsSync()) fail('スクリーンショット $name を撮れませんでした。');
  }

  testWidgets('現在のスタジオ画面をストア用に撮影する', (tester) async {
    await tester.pumpWidget(const TomoshibiApp(
      startUrl: 'https://tomoshibi.gikyokutosyokan.com/studio/?demo=2',
      requestTracking: false,
    ));
    final webView = find.byType(WebViewWidget);
    for (var i = 0; i < 120 && webView.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(webView, findsOneWidget);
    final controller = WebViewController.fromPlatform(
      tester.widget<WebViewWidget>(webView).platform.params.controller,
    );

    Future<void> waitFor(String expression) async {
      for (var i = 0; i < 160; i++) {
        try {
          if ((await controller.runJavaScriptReturningResult(expression)).toString() == 'true') return;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      fail('WebView内で条件を確認できませんでした: $expression');
    }

    Future<void> click(String selector) async {
      final result = await controller.runJavaScriptReturningResult('''(() => {
        const button = document.querySelector('$selector');
        if (!button) return false;
        button.click();
        return true;
      })()''');
      expect(result.toString(), 'true');
    }

    await waitFor("location.pathname === '/studio/' && document.body.innerText.includes('雨を待つ図書室')");
    await controller.runJavaScript('window.confirm = () => true;');
    await click('button[aria-label="名前をつけて保存"]');
    await waitFor("Boolean(document.querySelector('.scene-panel .scene-cta.primary'))");
    await click('.scene-panel .scene-cta.primary');
    await waitFor("document.body.innerText.includes('この端末に保存しました')");
    await click('.scene-panel .icon-btn');
    await Future<void>.delayed(const Duration(seconds: 6));
    await shoot(tester, '03_map');

    await click('button[aria-label="平面図を閉じる"]');
    await waitFor("document.querySelector('.unified-shell')?.classList.contains('map-hidden') === true");
    final outlineAlreadyOpen = (await controller.runJavaScriptReturningResult(
      "document.querySelector('.unified-shell')?.classList.contains('outline-visible') === true",
    )).toString() == 'true';
    if (outlineAlreadyOpen) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await shoot(tester, '04_scenes');
      await click('button[aria-label="シーン一覧を閉じる"]');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await shoot(tester, '02_3d');

    if (!outlineAlreadyOpen) {
      await click('.workspace-display-trigger');
      final showOutline = await controller.runJavaScriptReturningResult('''(() => {
        const button = [...document.querySelectorAll('.workspace-display-menu button')]
          .find(item => item.textContent?.includes('シーン一覧'));
        button?.click();
        return Boolean(button);
      })()''');
      expect(showOutline.toString(), 'true');
      await waitFor("document.querySelector('.unified-shell')?.classList.contains('outline-visible') === true");
      await Future<void>.delayed(const Duration(seconds: 1));
      await shoot(tester, '04_scenes');
      await click('button[aria-label="シーン一覧を閉じる"]');
    }
    await click('.workspace-play-button');
    await waitFor("Boolean(document.querySelector('.stage-playback'))");
    await Future<void>.delayed(const Duration(seconds: 2));
    await shoot(tester, '05_playback');

    await click('.stage-playback-close');
    await click('button[aria-label="プロジェクト一覧へ戻る"]');
    await waitFor("location.pathname === '/studio/projects/' && document.body.innerText.includes('雨を待つ図書室')");
    await Future<void>.delayed(const Duration(seconds: 1));
    await shoot(tester, '01_projects');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
