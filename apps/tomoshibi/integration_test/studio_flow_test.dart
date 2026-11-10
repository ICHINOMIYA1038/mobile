import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tomoshibi/main.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('プロジェクト編集と旧プラン移行をアプリ内で確認する', (tester) async {
    await tester.pumpWidget(const TomoshibiApp(requestTracking: false));
    final webView = find.byType(WebViewWidget);
    for (var i = 0; i < 120 && webView.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(webView, findsOneWidget);
    final controller = WebViewController.fromPlatform(
      tester.widget<WebViewWidget>(webView).platform.params.controller,
    );

    Future<String> evaluate(String expression) async {
      final result = await controller.runJavaScriptReturningResult(expression);
      return result.toString();
    }

    Future<void> waitFor(String expression, {int seconds = 35}) async {
      for (var i = 0; i < seconds * 4; i++) {
        try {
          if (await evaluate(expression) == 'true') return;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      fail('WebView内で条件を確認できませんでした: $expression');
    }

    Future<void> click(String selector) async {
      final query = jsonEncode(selector);
      expect(await evaluate('''(() => {
        const item = document.querySelector($query);
        if (!item) return false;
        item.click();
        return true;
      })()'''), 'true');
    }

    await waitFor("Boolean(document.querySelector('button.project-library-create'))");
    expect(find.text('購入を復元'), findsOneWidget);
    await click('button.project-library-create');
    await waitFor("location.pathname === '/studio/'");
    await click('button[aria-label*="シーン一覧を開く"]');
    await waitFor('''Boolean(document.querySelector('button[aria-label="第1章1の操作メニュー"]'))''');
    await click('button[aria-label="第1章1の操作メニュー"]');
    expect(await evaluate('''(() => {
      const button = [...document.querySelectorAll('[role="menuitem"]')]
        .find(item => item.textContent?.includes('この後にシーンを追加'));
      button?.click();
      return Boolean(button);
    })()'''), 'true');
    await waitFor("document.querySelector('.workspace-current-scene-picker strong')?.textContent === '第1章2'");
    await click('button[aria-label="シーン一覧を閉じる"]');
    await click('button[aria-label="プロジェクト一覧へ戻る"]');
    await waitFor("location.pathname === '/studio/projects/' && document.body.innerText.includes('2シーン')");
    await controller.reload();
    await waitFor("document.body.innerText.includes('2シーン')");

    final legacy = jsonEncode([
      {'version': 1, 'name': '旧プランA', 'savedAt': '2026-01-01T00:00:00Z', 'fixtures': [], 'performers': [], 'settings': {}},
      {'version': 1, 'name': '旧プランB', 'savedAt': '2026-01-02T00:00:00Z', 'fixtures': [], 'performers': [], 'settings': {}},
    ]);
    await controller.runJavaScript('localStorage.setItem("syoumei.scenes", ${jsonEncode(legacy)});');
    await controller.reload();
    await waitFor("document.body.innerText.includes('引き継いだ照明プラン')");
    expect(await evaluate('''(() => {
      const raw = JSON.parse(localStorage.getItem('syoumei.scenes') || '[]');
      return raw.length === 2 && raw[0].name === '旧プランA' && raw[1].name === '旧プランB';
    })()'''), 'true');
    expect(await evaluate('''(() => {
      const list = [...document.querySelectorAll('.project-library-list-item')];
      return list.filter(item => item.textContent?.includes('引き継いだ照明プラン')).length === 1 &&
        list.some(item => item.textContent?.includes('引き継いだ照明プラン') && item.textContent?.includes('2シーン'));
    })()'''), 'true');
    await controller.reload();
    await waitFor("document.body.innerText.includes('引き継いだ照明プラン')");
    expect(await evaluate('''[...document.querySelectorAll('.project-library-list-item')]
      .filter(item => item.textContent?.includes('引き継いだ照明プラン')).length === 1'''), 'true');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
