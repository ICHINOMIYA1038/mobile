import 'dart:io';

import 'package:doremi_scan/src/engine/cloud_omr_engine.dart';
import 'package:doremi_scan/src/screens/home_screen.dart';
import 'package:doremi_scan/src/screens/result_screen.dart';
import 'package:doremi_scan/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 方式は etude_generator と同じ（シミュレータの tmp にマーカーを置き、
/// tool/screenshots.sh 側が `xcrun simctl io screenshot` で撮る）。
/// 認識は本番のクラウドOMRを実際に呼ぶので、--dart-define で OMR_API_URL と
/// APP_KEY が要る（スクリプトが渡す）。サンプル楽譜はホストのファイルを
/// シミュレータから直接読む（シミュレータはホストのファイルシステムを共有する）。
const _samples = [
  '/Users/ichinomiya/private/doremi-omr/realtest/twinkle.png',
  '/Users/ichinomiya/private/doremi-omr/realtest/alouette.png',
];

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
    await tester.pump(const Duration(milliseconds: 300));
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

  /// 認識完了（表示切替のセグメントが出る）まで待つ。進捗リングが回り続けるので
  /// pumpAndSettle は使えない。
  Future<void> waitForResult(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 240));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
      // 撮影前チェックの「楽譜が小さく写っています」ダイアログはそのまま進める。
      final proceed = find.text('このまま読み取る');
      if (proceed.evaluate().isNotEmpty) {
        await tester.tap(proceed);
        await tester.pump(const Duration(seconds: 1));
        continue;
      }
      if (find.text('もどって撮り直す・選び直す').evaluate().isNotEmpty) {
        throw StateError('認識がエラーになりました: ${_visibleTexts()}');
      }
      if (find.text('きれいな楽譜', skipOffstage: false).evaluate().isNotEmpty ||
          find.text('PDFで共有', skipOffstage: false).evaluate().isNotEmpty ||
          find.text('印刷', skipOffstage: false).evaluate().isNotEmpty) {
        await tester.pump(const Duration(seconds: 2));
        return;
      }
    }
    throw StateError('認識が終わりませんでした。画面の文字: ${_visibleTexts()}');
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded_v1', true);
    for (final p in _samples) {
      if (!File(p).existsSync()) throw StateError('サンプルが見つかりません: $p');
    }
    final engine = CloudOmrEngine();

    // ResultScreen は同じ型・同じ位置に積むと State が再利用されて前の結果が
    // 残るので、必ず UniqueKey で作り直す。
    Widget result(String path) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: ResultScreen(key: UniqueKey(), engine: engine, imagePath: path),
        );

    // 1〜2枚目: きらきら星。清書 → 原本＋修正。
    await tester.pumpWidget(result(_samples[0]));
    await waitForResult(tester);
    await shoot(tester, '01_clean');
    final original = find.text('原本＋修正');
    if (original.evaluate().isNotEmpty) {
      await tester.tap(original);
      await tester.pump(const Duration(seconds: 1));
      await shoot(tester, '02_original');
    }

    // 3枚目: 2曲目（アルエット）の清書。
    await tester.pumpWidget(result(_samples[1]));
    await tester.pump(const Duration(seconds: 1));
    await waitForResult(tester);
    await shoot(tester, '03_second');

    // 4枚目: ホーム（履歴に2曲並んだ状態）。
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(key: UniqueKey(), engine: engine),
    ));
    await tester.pump(const Duration(seconds: 2));
    await shoot(tester, '04_home');
  });
}
