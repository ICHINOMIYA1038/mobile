import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdWidget;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/ads/ad_banner.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/screens/pro/plan_tasks.dart';
import 'package:takken_talk/state/app_state.dart';

// 広告と Pro の学習ツール:
//   (a) 新しい学習者（Pro でない）: ホームの下にバナー、「模擬試験」は Pro の案内を開く
//   (b) Pro の学習者: 広告なし、苦手分析でプランが出る（AI はモックなので記録から作るプラン）、模擬試験を始めて何問か答えて出し、点数と講評
// 手元のサイトに向けて動かす。Pro の学習者は先に作ってトークンを渡す（サイトのリポジトリで）:
//   curl -X POST http://localhost:3140/api/v1/users → { userId, token }
//   npx wrangler d1 execute pairof-shikaku --local --command "UPDATE users SET pro_until = 9999999999999 WHERE id = '<userId>'"
//   flutter test integration_test/pro_tools_test.dart -d <シミュレーター> --dart-define=API_BASE=http://localhost:3140 --dart-define=PRO_TOKEN=<token> --dart-define=PRO_USER=<userId>
// 「SHOT 名前」を出したところで数秒止まる（外から画面を撮るため）
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

  /// 見つかるまで待つ（最大 seconds 秒）
  Future<bool> waitFor(WidgetTester tester, Finder f, [int seconds = 20]) async {
    for (var i = 0; i < seconds * 10; i++) {
      if (f.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 100));
    }
    return f.evaluate().isNotEmpty;
  }

  /// ホームの「Pro の学習ツール」の行を見えるところまで動かして押す（下のバナーに隠れていることがある）
  Future<void> tapTool(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(find.text(title), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await tester.tap(find.text(title));
  }

  /// 一覧の中のその見出しを、画面の上のほうまで動かす
  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    final ctx = tester.element(f);
    // ignore: use_build_context_synchronously
    Scrollable.ensureVisible(ctx, alignment: 0.05);
    await settle(tester, 1);
  }

  Future<AppState> launch(WidgetTester tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);
    return state;
  }

  testWidgets('Pro でない人: バナーと Pro の案内', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ps_token');
    await prefs.remove('ps_user_id');
    final state = await launch(tester);
    expect(state.me?['pro'], isNot(true));
    expect(find.text('カリキュラム'), findsOneWidget);
    expect(find.text('Pro の学習ツール'), findsOneWidget);
    expect(find.byType(AdBanner), findsWidgets, reason: '学ぶの下にバナーの枠');
    // テスト広告が届くかは通信しだい（届かなければ枠は高さ 0 のまま）
    final loaded = await waitFor(tester, find.byType(AdWidget), 20);
    // ignore: avoid_print
    print('AD LOADED: $loaded');
    await tester.scrollUntilVisible(find.text('模擬試験（本番の比率で50問）'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 2);
    await shot(tester, 'p01_home_free');

    await tapTool(tester, '模擬試験（本番の比率で50問）');
    await settle(tester, 3);
    expect(find.text('模擬試験は Pro の機能です'), findsOneWidget);
    expect(find.text('広告が出なくなります。'), findsOneWidget);
    expect(find.byType(AdWidget), findsNothing, reason: 'Pro の画面に広告は出さない');
    await shot(tester, 'p02_pro_screen');
    await tester.tap(find.byType(CloseButton));
    await settle(tester, 2);

    // 苦手分析は Pro でなくても開ける（予測点と科目、Pro で見られるもの）。まだ答えていないので案内も
    await tapTool(tester, '苦手分析と学習プラン');
    expect(await waitFor(tester, find.text('Pro で見られるもの')), isTrue);
    expect(find.text('いまの予測点（本試験50問）'), findsOneWidget);
    expect(find.text('過去問を解くと、ここに分析が出ます'), findsOneWidget);
    expect(find.text('AI の学習プラン'), findsNothing);
    await shot(tester, 'p03_analysis_free');
    await scrollTo(tester, find.text('Pro で見られるもの'));
    await shot(tester, 'p03b_analysis_free_locked');
    await tester.pageBack();
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro の人: 広告なし・苦手分析・模擬試験', (tester) async {
    expect(_proToken, isNotEmpty, reason: '--dart-define=PRO_TOKEN=… が要る');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ps_token', _proToken);
    await prefs.setString('ps_user_id', _proUser);
    final state = await launch(tester);
    expect(state.me?['pro'], isTrue);
    await settle(tester, 4);
    expect(find.byType(AdWidget), findsNothing, reason: 'Pro の人に広告は出さない');

    // 苦手分析と学習プラン（プランは AI が書く。モックでは記録から作る簡易版）。記録は analysis.fixtures の「業法は得意、権利が苦手」
    await tapTool(tester, '苦手分析と学習プラン');
    expect(await waitFor(tester, find.text('AI の学習プラン'), 40), isTrue);
    expect(find.text('いまの予測点（本試験50問）'), findsOneWidget);
    expect(find.text('簡易版'), findsOneWidget);
    await shot(tester, 'a01_forecast');

    // 7日の予定: 今日の過去問のタスクを押して3問解き、戻ると「3/n問」に進む
    await scrollTo(tester, find.text('7日の予定'));
    await shot(tester, 'w01_week');
    final task = find.textContaining(RegExp(r'の過去問を\d+問$')).first;
    final taskText = (tester.widget<Text>(task)).data!;
    final goal = RegExp(r'(\d+)問$').firstMatch(taskText)!.group(1);
    final before = find.text('0/$goal問').evaluate().length;
    expect(before, greaterThan(0), reason: '今日の過去問のタスクはまだ0問');
    await tester.ensureVisible(task);
    await settle(tester, 1);
    await tester.tap(task);
    expect(await waitFor(tester, find.text('○ 正しい')), isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('○ 正しい').first);
      await settle(tester, 2);
      await tester.tap(find.textContaining(RegExp('次の問題|結果を見る')).first);
      await settle(tester, 2);
    }
    await tester.pageBack();
    expect(await waitFor(tester, find.text('3/$goal問'), 15), isTrue, reason: '戻ったら進み具合が増える');
    await scrollTo(tester, find.text('7日の予定'));
    await shot(tester, 'w02_progress');

    // 丸で済みにする → 今日がぜんぶ済む → 外す
    final circles = find.byType(CheckCircle);
    final undone = circles.evaluate().toList().indexWhere((e) => !(e.widget as CheckCircle).done);
    await tester.tap(circles.at(undone));
    await settle(tester, 2);
    if (find.text('今日の予定、ぜんぶできました').evaluate().isNotEmpty) await shot(tester, 'w03_all_done');
    expect((tester.widget<CheckCircle>(circles.at(undone))).done, isTrue);
    await tester.tap(circles.at(undone));
    await settle(tester, 2);
    expect((tester.widget<CheckCircle>(circles.at(undone))).done, isFalse);
    for (final (title, name) in const [
      ('AI の学習プラン', 'a02_plan'),
      ('7日の予定', 'a02b_plan_week'),
      ('優先したい論点', 'a03_priorities'),
      ('章ごとの出来', 'a04_chapters'),
      ('まちがい方の癖', 'a05_habits'),
      ('学習量とペース', 'a06_pace'),
      ('まだ解いていない頻出論点', 'a07_untouched'),
    ]) {
      await scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget, reason: title);
      await shot(tester, name);
      if (name == 'a03_priorities') {
        // まちがえた問題を開く
        await tester.tap(find.textContaining('まちがえた問題 ').first);
        await settle(tester, 2);
        expect(find.textContaining('あなたの答え'), findsWidgets);
        await shot(tester, 'a03b_priority_missed');
      }
    }
    expect(find.textContaining('プランを作り直す'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 3);

    // ホームの「今日の予定」
    expect(await waitFor(tester, find.byKey(const ValueKey('today_card'))), isTrue);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('today_card')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    expect(find.text('3/$goal問'), findsOneWidget);
    await shot(tester, 'h01_today');
    final homeCircles = find.descendant(of: find.byKey(const ValueKey('today_card')), matching: find.byType(CheckCircle));
    final homeUndone = homeCircles.evaluate().toList().indexWhere((e) => !(e.widget as CheckCircle).done);
    if (homeUndone >= 0) {
      await tester.tap(homeCircles.at(homeUndone));
      await settle(tester, 3);
      if (find.text('今日の予定、ぜんぶできました').evaluate().isNotEmpty) await shot(tester, 'h02_today_all_done');
      await tester.tap(homeCircles.at(homeUndone));
      await settle(tester, 3);
    }

    // 模擬試験
    await tapTool(tester, '模擬試験（本番の比率で50問）');
    await settle(tester, 3);
    expect(find.text('本番と同じ比率で50問・30分'), findsOneWidget);
    await shot(tester, 'p05_mock_intro');
    await tester.tap(find.text('始める（30分）'));
    expect(await waitFor(tester, find.byKey(const ValueKey('mock_true'))), isTrue);
    expect(find.text('1/50'), findsOneWidget);
    for (final a in [true, false, true, true, false]) {
      await tester.tap(find.byKey(ValueKey(a ? 'mock_true' : 'mock_false')));
      await settle(tester, 1);
    }
    expect(find.text('6/50'), findsOneWidget);
    expect(find.byType(AdWidget), findsNothing, reason: '模擬試験に広告は出さない');
    await shot(tester, 'p06_mock_question');

    // 閉じるボタンでは「やめますか」と聞く
    await tester.tap(find.byTooltip('やめる'));
    await settle(tester, 1);
    expect(find.text('模擬試験をやめますか？'), findsOneWidget);
    await tester.tap(find.text('続ける'));
    await settle(tester, 1);

    // 見直しの一覧から答えを出す
    await tester.tap(find.byKey(const ValueKey('mock_review')));
    await settle(tester, 2);
    expect(find.textContaining('見直し（答えた 5'), findsOneWidget);
    await shot(tester, 'p07_mock_review');
    await tester.tap(find.widgetWithText(FilledButton, '答えを出す').last);
    await settle(tester, 2);
    expect(find.textContaining('まだ答えていない問題が 45問'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mock_submit_ok')));
    expect(await waitFor(tester, find.text('AI の講評'), 40), isTrue);
    expect(find.textContaining('合格点の目安'), findsWidgets);
    expect(find.text('問題ごとの答え'), findsOneWidget);
    await shot(tester, 'p08_mock_result');

    // 一覧（すべて・まちがえた・未回答）
    await scrollTo(tester, find.text('問題ごとの答え'));
    await shot(tester, 'p09_mock_result_list');
    await tester.tap(find.byKey(const ValueKey('mock_filter_blank')));
    await settle(tester, 1);
    expect(find.textContaining('あなたの答え 未回答'), findsWidgets);
    await shot(tester, 'p09b_mock_result_blank');
    await tester.tap(find.byKey(const ValueKey('mock_filter_all')));
    await settle(tester, 1);

    // 1問ずつ: 問題文・○/×（自分の答えと正しい答え）・解説・根拠・出典、前へ・次へ
    final first = find.textContaining(RegExp(r'^問1  '));
    await tester.ensureVisible(first);
    await settle(tester, 1);
    await tester.tap(first);
    await settle(tester, 2);
    expect(find.text('問1（1/50）'), findsOneWidget);
    expect(find.text('解説'), findsOneWidget);
    expect(find.text('この論点を先生と学ぶ'), findsOneWidget);
    expect(find.textContaining('あなたの答え'), findsWidgets);
    await shot(tester, 'p10_mock_item');
    await tester.tap(find.byKey(const ValueKey('mock_item_next')));
    await settle(tester, 1);
    expect(find.text('問2（2/50）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mock_item_next')));
    await tester.tap(find.byKey(const ValueKey('mock_item_next')));
    await tester.tap(find.byKey(const ValueKey('mock_item_next')));
    await tester.tap(find.byKey(const ValueKey('mock_item_next')));
    await settle(tester, 1);
    expect(find.text('問6（6/50）'), findsOneWidget);
    expect(find.text('この問題は未回答でした。'), findsOneWidget);
    await shot(tester, 'p11_mock_item_blank');
    await tester.tap(find.byKey(const ValueKey('mock_item_prev')));
    await settle(tester, 1);
    expect(find.text('問5（5/50）'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 2);

    // 記録に残っている
    expect(await waitFor(tester, find.text('これまでの結果')), isTrue);
    expect(find.textContaining('/ 50点'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
