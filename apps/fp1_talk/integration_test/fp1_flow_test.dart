import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/state/app_state.dart';

/// 通しの確認: 起動 → 下のタブを全部開く → 章の会話 → 本試験形式（基礎編の四答択一・応用編の計算と電卓）。
/// 手元のサイトに向けて動かす（AI はモックの定型文。サイトの worktree で `pnpm dev --port 3150`）:
///   tool/shots.sh <シミュレーターの UDID> tool/shots integration_test/fp1_flow_test.dart --dart-define=API_BASE=http://localhost:3150
/// 「SHOT 名前」を出したところで tool/shots.sh が画面を撮る。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('SHOT $name');
    await settle(tester, 3);
  }

  Finder tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await settle(tester, 1);
    await tester.tap(f);
  }

  testWidgets('タブ・会話・本試験形式（四答択一・計算・電卓）', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);
    expect(find.text('カリキュラム'), findsOneWidget);
    expect(find.text('pAIrOf FP1級'), findsOneWidget);
    await shot(tester, '01_home');

    for (final t in ['本試験形式', '復習', '図解', '設定', '学ぶ']) {
      await tester.tap(tab(t));
      await settle(tester, 3);
      expect(tester.takeException(), isNull, reason: t);
    }

    // 章の会話（最初の説明が流れてくる。AI はモック）
    await tester.tap(find.textContaining('から始める').first);
    await settle(tester, 10);
    expect(find.byType(TextField), findsWidgets);
    expect(find.textContaining('こんにちは'), findsWidgets, reason: '先生の最初の一言');
    // 自分で送ると返答が流れてくる
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '在職老齢年金がわからない');
    await settle(tester, 1);
    await tester.tap(find.widgetWithText(FilledButton, '送る'), warnIfMissed: false);
    await settle(tester, 8);
    expect(find.textContaining('開発モード'), findsWidgets, reason: 'モックの AI の返答');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 2);
    await shot(tester, '02_chat');
    await tester.pageBack();
    await settle(tester, 2);
    expect(find.text('カリキュラム'), findsOneWidget, reason: '会話から戻れる');

    // 本試験形式の一覧（回ごと）
    await tester.tap(tab('本試験形式'));
    await settle(tester, 3);
    expect(find.text('2026年9月'), findsOneWidget);
    await shot(tester, '03_items');

    // 基礎編: 四答択一は押したらすぐ答え合わせ。選択肢ごとの解説が出る
    await tester.tap(find.byKey(const Key('items-2026-09-kiso')));
    await settle(tester, 4);
    expect(find.text('1 / 50問'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('option-1')));
    await settle(tester, 3);
    expect(find.byKey(const Key('item-result')), findsOneWidget);
    expect(find.text('正解'), findsWidgets, reason: '正解の選択肢に印');
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await settle(tester, 1);
    await shot(tester, '04_kiso_choice');
    await tester.pageBack();
    await settle(tester, 3);
    expect(find.textContaining('解いた 1'), findsWidgets, reason: '戻ったら解いた数が増える');

    // 応用編: 設例（折りたためる）と計算問題（問53）。欄に答え・計算過程を書き、電卓で確かめて答え合わせ
    await tapVisible(tester, find.byKey(const Key('items-2026-09-ouyou')));
    await settle(tester, 4);
    expect(find.textContaining('《設例》'), findsOneWidget);
    await shot(tester, '05_ouyou_case');
    await tester.tap(find.byKey(const Key('case-toggle')));
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('item-next')));
    await settle(tester, 2);
    await tapVisible(tester, find.byKey(const Key('item-next')));
    await settle(tester, 2);
    expect(find.text('3 / 15問'), findsOneWidget);
    expect(find.byKey(const Key('process-①')), findsOneWidget, reason: '計算過程の欄');

    // 電卓（押した順に計算・丸めない）
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);
    for (final k in '8 4 7 3 0 0 × 4 5 2 ÷ 4 8 0 ='.split(' ')) {
      await tester.tap(find.byKey(Key('calc-$k')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await settle(tester, 1);
    expect(tester.widget<Text>(find.byKey(const Key('calc-display'))).data, '797,874.166667');
    await shot(tester, '06_calculator');
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);

    await tapVisible(tester, find.byKey(const Key('part-①')));
    await tester.enterText(find.byKey(const Key('part-①')), '797874');
    await tapVisible(tester, find.byKey(const Key('process-①')));
    await tester.enterText(find.byKey(const Key('process-①')), '847,300×452/480＝797,874');
    await tapVisible(tester, find.byKey(const Key('part-②')));
    await tester.enterText(find.byKey(const Key('part-②')), '1000000');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('item-grade')));
    await settle(tester, 4);
    expect(find.byKey(const Key('item-result')), findsOneWidget);
    expect(find.textContaining('欄 正解'), findsOneWidget, reason: '欄ごとに採点');
    expect(find.text('模範の計算過程'), findsWidgets);
    await tapVisible(tester, find.text('模範の計算過程').first);
    await settle(tester, 1);
    await tester.ensureVisible(find.text('模範の計算過程').first);
    await settle(tester, 1);
    await shot(tester, '07_ouyou_result');
    expect(tester.takeException(), isNull);
  });
}
