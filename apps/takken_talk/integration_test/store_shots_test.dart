import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/state/app_state.dart';

/// ストアの画像の素材を撮る（本番・本物の AI）。「SHOT 名前」で外から撮る（tool/store_shots.sh）。
/// 価格・「無料」が写る画面は撮らない（Guideline 2.3.7）。
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

  /// 本物の AI の返答を待つ（送るボタンが使えるようになるまで）
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
    // 前の返答が流れている間は送れない。送れる（入力欄が空になる）まで押し直す
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
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester, 6);

    // 会話: 最初の説明 → 図 → ○×
    await tester.tap(find.textContaining('から始める').first);
    await waitReply(tester);
    await say(tester, '図で見せてください');
    await shot(tester, '01_chat_figure');
    await say(tester, '宅地に当たる。次は○×の問題を出してください');
    await shot(tester, '02_chat_question');
    await tester.pageBack();
    await settle(tester, 2);

    // ホーム（章の一覧と、章の過去問への入口）
    await shot(tester, '03_home');

    // 過去問: 章ごとの一覧
    await tester.tap(find.text('過去問').last);
    await settle(tester, 3);
    await shot(tester, '04_kakomon');

    // 過去問を1問解いて AIに聞く
    await tester.tap(find.text('回ごと'));
    await settle(tester, 1);
    await tester.tap(find.text('令和7年度').first);
    await settle(tester, 8);
    await tester.tap(find.text('× 誤り').first);
    await settle(tester, 3);
    await shot(tester, '05_kakomon_answered');
    await tester.tap(find.text('AIに聞く').last);
    await settle(tester, 3);
    await tester.tap(find.textContaining('なぜ').first);
    await settle(tester, 40);
    await shot(tester, '06_explain');
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 2);

    // 図解ライブラリ
    await tester.tap(find.text('図解').last);
    await settle(tester, 4);
    await shot(tester, '07_library');
    expect(tester.takeException(), isNull);
  });
}
