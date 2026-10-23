import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/state/app_state.dart';
import 'package:fp1_talk/widgets/figure/figure_view.dart';

/// ストアの画像の素材を撮る（本物の AI）。「SHOT 名前」で外から撮る（tool/store_shots.sh）。
/// 価格・「無料」が写る画面は撮らない（Guideline 2.3.7）。広告が写らないように Pro の学習者で撮る。
/// 手元のサイト（.dev.vars を本物のキーに差し替えたもの）に、学習の記録を入れた Pro の学習者を作ってトークンを渡す
/// （作り方は fp1_pro_test.dart の頭と同じ。記録は /answer・/item-answer に送って入れる）:
///   `tool/store_shots.sh <UDID> <出力先> --dart-define=API_BASE=http://localhost:3130 --dart-define=PRO_TOKEN=<token> --dart-define=PRO_USER=<userId>`
const _proToken = String.fromEnvironment('PRO_TOKEN');
const _proUser = String.fromEnvironment('PRO_USER');

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

  Future<bool> waitFor(WidgetTester tester, Finder f, [int seconds = 20]) async {
    for (var i = 0; i < seconds * 10; i++) {
      if (f.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 100));
    }
    return f.evaluate().isNotEmpty;
  }

  Finder tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await settle(tester, 1);
    await tester.tap(f);
  }

  /// 本物の AI の返答を待つ（送るボタンが使えて、選択肢のチップが出るまで）
  Future<void> waitReply(WidgetTester tester, {int seconds = 60}) async {
    await settle(tester, 4);
    for (var i = 0; i < seconds; i++) {
      await settle(tester, 1);
      final send = find.widgetWithText(FilledButton, '送る');
      if (send.evaluate().isNotEmpty && find.byType(CircularProgressIndicator).evaluate().isEmpty && find.byType(ActionChip).evaluate().isNotEmpty) return;
    }
  }

  /// 文字で送って返答を待ち、最新の返答まで送る
  Future<void> say(WidgetTester tester, String text) async {
    await tester.tap(find.byType(TextField).first);
    await settle(tester, 1);
    await tester.enterText(find.byType(TextField).first, text);
    await settle(tester, 1);
    String typed() => tester.widget<TextField>(find.byType(TextField).first).controller?.text ?? '';
    for (var i = 0; i < 20 && typed().isNotEmpty; i++) {
      await tester.tap(find.widgetWithText(FilledButton, '送る'), warnIfMissed: false);
      await settle(tester, 3);
    }
    await settle(tester, 6);
    await waitReply(tester);
    await settle(tester, 4);
    final jump = find.text('↓ 最新の返答へ');
    if (jump.evaluate().isNotEmpty) {
      await tester.tap(jump.first);
      await settle(tester, 2);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 2);
  }

  testWidgets('ストアの画像', (tester) async {
    expect(_proToken, isNotEmpty, reason: '--dart-define=PRO_TOKEN=… が要る');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ps_token', _proToken);
    await prefs.setString('ps_user_id', _proUser);
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester, 6);
    expect(state.me?['pro'], isTrue);
    await shot(tester, 'home');

    // 会話: 最初の説明 → 図 → ○×
    // 初めての人は「…から始める」、続きがある人は「前回の続きから」の下のボタン（章の名前）
    final start = find.textContaining('から始める');
    await tester.tap(start.evaluate().isNotEmpty ? start.first : find.textContaining('第1章').first);
    await waitReply(tester);
    await shot(tester, 'chat_first');
    // 「図で見せて」のチップ（まだ見ていない図がある論点で出る）。無ければ文字で頼む
    final figChip = find.widgetWithText(ActionChip, '図で見せて');
    if (figChip.evaluate().isNotEmpty) {
      await tester.tap(figChip.first);
      await settle(tester, 6);
      await waitReply(tester);
      await settle(tester, 3);
    } else {
      await say(tester, 'この論点を図で見せてください');
    }
    await shot(tester, 'chat_figure');
    // 返答が流れて図が上に隠れていたら、図が画面の上の方に来るまで戻す
    final fig = find.byType(FigureView);
    if (fig.evaluate().isNotEmpty) {
      // ignore: use_build_context_synchronously
      Scrollable.ensureVisible(tester.element(fig.last), alignment: 0.15);
      await settle(tester, 2);
      await shot(tester, 'chat_figure_view');
    }
    await say(tester, 'わかりました。次は○×の問題を出してください');
    await shot(tester, 'chat_question');
    await tester.pageBack();
    await settle(tester, 2);

    // 本試験形式: 一覧 → 基礎編（選択肢ごとの解説）→ AIに聞く
    await tester.tap(tab('本試験形式'));
    await settle(tester, 3);
    await shot(tester, 'items');
    await tapVisible(tester, find.byKey(const Key('items-2026-09-kiso')));
    expect(await waitFor(tester, find.byKey(const Key('option-1'))), isTrue);
    await shot(tester, 'kiso_question');
    await tapVisible(tester, find.byKey(const Key('option-1')));
    expect(await waitFor(tester, find.byKey(const Key('item-result'))), isTrue);
    await tester.ensureVisible(find.byKey(const Key('item-result')));
    await settle(tester, 2);
    await shot(tester, 'kiso_result');
    await tapVisible(tester, find.byKey(const Key('item-ask')));
    expect(await waitFor(tester, find.byKey(const Key('explain-cta'))), isTrue);
    await tester.tap(find.byKey(const Key('explain-cta')));
    await settle(tester, 45);
    await shot(tester, 'kiso_ask');
    await tester.tap(find.text('問題に戻る'));
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 3);

    // 応用編: 設例 → 計算問題（電卓・計算過程・欄ごとの採点）
    await tapVisible(tester, find.byKey(const Key('items-2026-09-ouyou')));
    await settle(tester, 4);
    await shot(tester, 'ouyou_case');
    await tester.tap(find.byKey(const Key('case-toggle')));
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('item-next')));
    await settle(tester, 2);
    await tapVisible(tester, find.byKey(const Key('item-next')));
    await settle(tester, 2);
    await tapVisible(tester, find.byKey(const Key('part-①')));
    await tester.enterText(find.byKey(const Key('part-①')), '797874');
    await tapVisible(tester, find.byKey(const Key('process-①')));
    await tester.enterText(find.byKey(const Key('process-①')), '847,300×452/480＝797,874');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);
    for (final k in '8 4 7 3 0 0 × 4 5 2 ÷ 4 8 0 ='.split(' ')) {
      await tester.tap(find.byKey(Key('calc-$k')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await settle(tester, 1);
    await shot(tester, 'ouyou_calc');
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('part-②')));
    await tester.enterText(find.byKey(const Key('part-②')), '1498822');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('item-grade')));
    await settle(tester, 4);
    await tester.ensureVisible(find.byKey(const Key('item-result')));
    await settle(tester, 2);
    await shot(tester, 'ouyou_result');
    await tester.pageBack();
    await settle(tester, 3);

    // 図解ライブラリ・復習
    await tester.tap(tab('図解'));
    await settle(tester, 4);
    await shot(tester, 'library');
    await tester.tap(tab('復習'));
    await settle(tester, 4);
    await shot(tester, 'review');

    // Pro: 苦手分析（200点満点の予測点・AI の学習プラン）
    await tester.tap(tab('学ぶ'));
    await settle(tester, 3);
    await tester.scrollUntilVisible(find.byKey(const Key('tool-analysis')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('tool-analysis')));
    expect(await waitFor(tester, find.text('AI の学習プラン'), 90), isTrue);
    await settle(tester, 3);
    await shot(tester, 'analysis_top');
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, 2);
      await shot(tester, 'analysis_$i');
    }
    await tester.pageBack();
    await settle(tester, 3);

    // Pro: 模擬試験（入口 → 基礎編を解く画面と電卓）
    await tester.scrollUntilVisible(find.byKey(const Key('tool-mock')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('tool-mock')));
    expect(await waitFor(tester, find.byKey(const Key('mock-start-kiso'))), isTrue);
    await settle(tester, 2);
    await shot(tester, 'mock_intro');
    await tapVisible(tester, find.byKey(const Key('mock-start-kiso')));
    expect(await waitFor(tester, find.byKey(const Key('mock-clock'))), isTrue);
    await tapVisible(tester, find.byKey(const Key('option-2')));
    await settle(tester, 2);
    await shot(tester, 'mock_kiso');
    await tester.tap(find.byKey(const Key('mock-list')));
    await settle(tester, 2);
    await shot(tester, 'mock_list');
    expect(tester.takeException(), isNull);
  });
}
