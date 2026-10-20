import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/state/app_state.dart';

/// 本番（shikaku.pairof.jp・本物の AI）に向けた通しの確認。審査に出す前に回す:
///   flutter test integration_test/prod_check_test.dart -d <シミュレーター>
/// 会話・キーボードでの入力・過去問の AIに聞く・Pro の画面。「SHOT 名前」で外から画面を撮る
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

  /// 本物の AI の返答を待つ（送れるようになるまで。最大 [seconds] 秒）
  Future<void> waitReply(WidgetTester tester, {int seconds = 60}) async {
    for (var i = 0; i < seconds; i++) {
      await settle(tester, 1);
      final ready = find.widgetWithText(FilledButton, '送る');
      final field = find.byType(TextField);
      if (ready.evaluate().isNotEmpty && field.evaluate().isNotEmpty && (tester.widget<TextField>(field.first).enabled ?? true) && i > 3) {
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      }
    }
  }

  testWidgets('本番で会話・入力・AIに聞く・Pro', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester, 6);
    expect(find.text('カリキュラム'), findsOneWidget);
    await shot(tester, 'p01_home');

    // 章の会話: 最初の一言 → キーボードで質問
    await tester.tap(find.textContaining('から始める').first);
    await waitReply(tester);
    await shot(tester, 'p02_first');
    await tester.tap(find.byType(TextField).first);
    await settle(tester, 1);
    await tester.enterText(find.byType(TextField).first, '自分の家を1回売るだけでも免許はいりますか？');
    await settle(tester, 1);
    await shot(tester, 'p03_typing');
    await tester.tap(find.widgetWithText(FilledButton, '送る'));
    await settle(tester, 2);
    await waitReply(tester);
    await shot(tester, 'p04_reply');
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await settle(tester, 2);

    // 過去問で1問答えて AIに聞く
    await tester.tap(find.text('過去問').last);
    await settle(tester, 3);
    await tester.tap(find.text('回ごと'));
    await settle(tester, 1);
    await tester.tap(find.text('令和7年度').first);
    await settle(tester, 8);
    await tester.tap(find.text('○ 正しい').first);
    await settle(tester, 3);
    await tester.tap(find.text('AIに聞く').last);
    await settle(tester, 3);
    await tester.tap(find.textContaining('なぜ').first);
    await settle(tester, 40);
    await shot(tester, 'p05_explain');
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 2);

    // 設定 → Pro の画面（値段は App Store のサンドボックスから）
    await tester.tap(find.text('設定').last);
    await settle(tester, 3);
    await shot(tester, 'p06_settings');
    await tester.tap(find.text('1日に AI と話せる回数を増やす'));
    await settle(tester, 15);
    await shot(tester, 'p07_pro');
    expect(tester.takeException(), isNull);
  });
}
