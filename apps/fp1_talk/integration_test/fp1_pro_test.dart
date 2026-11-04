import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/state/app_state.dart';

// FP1 の Pro の学習ツールと本試験形式の「AIに聞く」・復習:
//   模擬試験（基礎編: 四答択一を選んで出す → 結果 → 問ごとの見直し・AIに聞く／応用編: 欄を書いて出す）→ 苦手分析（200点満点の予測点）
//   → 本試験形式の「AIに聞く」→ 復習の「本試験形式でまちがえた問」から解き直す
// 手元のサイト（AI はモック）に向けて動かす。Pro の学習者は先に作ってトークンを渡す（サイトの worktree で）:
//   curl -X POST http://localhost:3170/api/v1/users → { userId, token }
//   npx wrangler d1 execute pairof-shikaku --local --command "INSERT INTO entitlements (user_id, exam, until, product, updated_at) VALUES ('<userId>', 'fp1', 9999999999999, 'jp.pairof.fp1.talk.pro.monthly', 0)"
//   tool/shots.sh <UDID> tool/shots integration_test/fp1_pro_test.dart --dart-define=API_BASE=http://localhost:3170 --dart-define=PRO_TOKEN=<token> --dart-define=PRO_USER=<userId>
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

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    // ignore: use_build_context_synchronously
    Scrollable.ensureVisible(tester.element(f), alignment: 0.05);
    await settle(tester, 1);
  }

  /// 「AIに聞く」を開いて最初の頼みを送り、モックの返答が流れてくるのを待つ
  Future<void> askAi(WidgetTester tester, String shotName) async {
    await tapVisible(tester, find.byKey(const Key('item-ask')));
    expect(await waitFor(tester, find.byKey(const Key('explain-cta'))), isTrue, reason: 'シートの最初の頼み');
    // 前に同じ問で聞いていれば、その会話の下にある（見えるところまで動かしてから押す）
    final before = find.textContaining('開発モードの定型文').evaluate().length;
    await tester.ensureVisible(find.byKey(const Key('explain-cta')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('explain-cta')));
    for (var i = 0; i < 200 && find.textContaining('開発モードの定型文').evaluate().length <= before; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('開発モードの定型文').evaluate().length, greaterThan(before), reason: 'モックの AI の返答が新しく届く');
    await settle(tester, 2);
    expect(find.byKey(const Key('explain-cta')), findsNothing, reason: '聞いたあとは最初の頼みを出さない');
    expect(find.textContaining('話せる回数'), findsOneWidget, reason: '1日に話せる回数から減ることを書く（期間限定で上限なしのときは「今日あと」は出ない）');
    await shot(tester, shotName);
    await tester.tap(find.text('問題に戻る'));
    await settle(tester, 2);
  }

  testWidgets('Pro の人: 模擬試験・予測点・本試験形式の「AIに聞く」・復習', (tester) async {
    expect(_proToken, isNotEmpty, reason: '--dart-define=PRO_TOKEN=… が要る');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ps_token', _proToken);
    await prefs.setString('ps_user_id', _proUser);
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);
    expect(state.me?['pro'], isTrue);

    // ---------- 模擬試験: 基礎編 ----------
    await tester.scrollUntilVisible(find.byKey(const Key('tool-mock')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await shot(tester, 'p01_home_tools');
    await tester.tap(find.byKey(const Key('tool-mock')));
    expect(await waitFor(tester, find.byKey(const Key('mock-start-kiso'))), isTrue);
    expect(find.textContaining('200点満点'), findsWidgets);
    expect(find.textContaining('150分'), findsWidgets);
    expect(find.textContaining('配点は推定'), findsWidgets, reason: '応用編の配点は推定と書く');
    await shot(tester, 'm01_mock_intro');

    await tapVisible(tester, find.byKey(const Key('mock-start-kiso')));
    expect(await waitFor(tester, find.byKey(const Key('mock-clock'))), isTrue);
    expect(find.textContaining('残り 2:'), findsOneWidget, reason: '150分');
    expect(find.text('1 / 50問'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('option-2')));
    await settle(tester, 1);
    expect(find.text('選んだ答え'), findsOneWidget);
    expect(find.byKey(const Key('item-result')), findsNothing, reason: '模擬試験ではその場で答え合わせしない');
    await shot(tester, 'm02_mock_kiso');
    await tapVisible(tester, find.byKey(const Key('item-next')));
    await settle(tester, 1);
    await tapVisible(tester, find.byKey(const Key('option-1')));
    await settle(tester, 1);
    // 電卓
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);
    for (final k in '1 2 0 × 2 ='.split(' ')) {
      await tester.tap(find.byKey(Key('calc-$k')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await settle(tester, 1);
    expect(tester.widget<Text>(find.byKey(const Key('calc-display'))).data, '240');
    await shot(tester, 'm03_mock_calc');
    await tester.tap(find.byKey(const Key('calc-toggle')));
    await settle(tester, 1);
    // 問の一覧（答えた問に色）
    await tester.tap(find.byKey(const Key('mock-list')));
    await settle(tester, 2);
    await shot(tester, 'm04_mock_list');
    await tester.tap(find.byKey(const Key('mock-jump-3')));
    await settle(tester, 2);
    expect(find.text('3 / 50問'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mock-submit')));
    await settle(tester, 2);
    expect(find.textContaining('まだ答えていない問が 48問'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mock-submit-ok')));
    expect(await waitFor(tester, find.byKey(const Key('mock-score')), 30), isTrue);
    expect(find.textContaining('/ 100点'), findsWidgets);
    expect(find.textContaining('合格点の目安（60点）'), findsWidgets);
    await shot(tester, 'm05_mock_result');
    await scrollTo(tester, find.text('問ごとの答え'));
    await shot(tester, 'm06_mock_result_items');

    // 問1を見直す: 自分の答え・正解・解説、AIに聞く
    await tapVisible(tester, find.byKey(const Key('mock-item-1')));
    expect(await waitFor(tester, find.byKey(const Key('item-result'))), isTrue);
    expect(find.text('正解'), findsWidgets, reason: '正解の選択肢に印');
    await tester.ensureVisible(find.byKey(const Key('item-result')));
    await settle(tester, 1);
    await shot(tester, 'm07_mock_review');
    await askAi(tester, 'm08_mock_review_ask');
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    expect(await waitFor(tester, find.text('これまでの結果')), isTrue);
    await settle(tester, 2);
    expect(find.textContaining('基礎編'), findsWidgets);
    expect(find.text('本試験形式の問題や模擬試験に答えると、ここに予測点が出ます。'), findsNothing, reason: '答えたので予測点が出る');
    await shot(tester, 'm09_mock_intro_after');

    // ---------- 模擬試験: 応用編（設例。欄を書いて出す）----------
    await tapVisible(tester, find.byKey(const Key('mock-start-ouyou')));
    expect(await waitFor(tester, find.byKey(const Key('mock-clock'))), isTrue);
    expect(find.textContaining('《設例》'), findsOneWidget);
    expect(find.textContaining('（推定）'), findsWidgets, reason: '欄の配点は推定');
    final field = find.byWidgetPredicate((w) => w is TextField && (w.key is ValueKey<String>) && (w.key as ValueKey<String>).value.startsWith('part-'));
    expect(await waitFor(tester, field), isTrue);
    await tapVisible(tester, field.first);
    await tester.enterText(field.first, '1');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await shot(tester, 'm10_mock_ouyou');
    await tester.tap(find.byKey(const Key('mock-submit')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('mock-submit-ok')));
    expect(await waitFor(tester, find.byKey(const Key('mock-score')), 30), isTrue);
    expect(find.textContaining('応用編の配点は公表されていないため推定'), findsOneWidget);
    await shot(tester, 'm11_mock_ouyou_result');
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 3);

    // ---------- 苦手分析（200点満点の予測点） ----------
    await tester.scrollUntilVisible(find.byKey(const Key('tool-analysis')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('tool-analysis')));
    expect(await waitFor(tester, find.text('AI の学習プラン'), 40), isTrue);
    expect(find.text('いまの予測点（200点満点）'), findsOneWidget);
    expect(find.byKey(const Key('forecast-kiso')), findsOneWidget);
    expect(find.byKey(const Key('forecast-ouyou')), findsOneWidget);
    await shot(tester, 'a01_forecast');
    await scrollTo(tester, find.text('まちがい方の癖'));
    await shot(tester, 'a02_habits');
    await tester.pageBack();
    await settle(tester, 3);

    // ---------- 本試験形式の「AIに聞く」（過去問演習） ----------
    await tester.tap(tab('本試験形式'));
    await settle(tester, 3);
    await tapVisible(tester, find.byKey(const Key('items-2026-09-kiso')));
    expect(await waitFor(tester, find.byKey(const Key('option-1'))), isTrue);
    await tapVisible(tester, find.byKey(const Key('option-1')));
    expect(await waitFor(tester, find.byKey(const Key('item-result'))), isTrue);
    await askAi(tester, 'i01_item_ask');
    await tester.pageBack();
    await settle(tester, 2);

    // ---------- 復習: 本試験形式でまちがえた問 ----------
    await tester.tap(tab('復習'));
    await settle(tester, 3);
    await tester.tap(find.textContaining('まちがえた ').first);
    await settle(tester, 2);
    expect(find.byKey(const Key('review-items')), findsOneWidget);
    await shot(tester, 'r01_review_items');
    await tester.tap(find.byKey(const Key('review-items-solve')));
    expect(await waitFor(tester, find.byKey(const Key('item-pos'))), isTrue);
    expect(find.text('本試験形式でまちがえた問'), findsOneWidget);
    await shot(tester, 'r02_review_solve');
    await tester.pageBack();
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
  });
}
