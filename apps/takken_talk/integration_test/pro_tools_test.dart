import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show AdWidget;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/ads/ad_banner.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
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

    // 苦手分析は Pro でなくても開ける（科目ごとの正答率と、Pro で見られるもの）
    await tapTool(tester, '苦手分析と学習プラン');
    expect(await waitFor(tester, find.text('Pro で見られるもの')), isTrue);
    expect(find.text('科目ごとの正答率'), findsOneWidget);
    await shot(tester, 'p03_analysis_free');
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

    // 苦手分析と学習プラン（プランは AI が書く。モックでは記録から作るプラン）
    await tapTool(tester, '苦手分析と学習プラン');
    expect(await waitFor(tester, find.text('今週の学習プラン'), 40), isTrue);
    expect(find.textContaining('7日の目安'), findsOneWidget);
    expect(find.textContaining('プランを作り直す'), findsOneWidget);
    await shot(tester, 'p04_analysis_pro');
    await tester.pageBack();
    await settle(tester, 2);

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

    // 問題を開くと解説と「この論点を先生と学ぶ」
    final first = find.textContaining('問1 ');
    await tester.scrollUntilVisible(first, 300, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await tester.tap(first);
    await settle(tester, 2);
    expect(find.text('この論点を先生と学ぶ'), findsWidgets);
    await shot(tester, 'p09_mock_result_item');
    await tester.pageBack();
    await settle(tester, 2);

    // 記録に残っている
    expect(await waitFor(tester, find.text('これまでの結果')), isTrue);
    expect(find.textContaining('/ 50点'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
