import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/state/app_state.dart';

/// 会話と過去問の行き来: ホームの「この章の過去問」→ 答えて「この論点を先生と学ぶ」→ 会話でその論点の説明
/// → 「この論点の過去問」→ 答えて戻るボタンで会話に戻る。過去問のタブの「章ごと」。
/// 手元のサイトに向けて動かす（AI はモック）:
///   flutter test integration_test/links_test.dart -d <シミュレーター> --dart-define=API_BASE=http://localhost:3140
/// 「SHOT 名前」を出したところで数秒止まる（外から画面を撮るため）
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

  testWidgets('会話と過去問の行き来', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);

    // ホーム: 章の行の下に「この章の過去問を解く」
    final toKakomon = find.textContaining('この章の過去問を解く');
    expect(toKakomon, findsWidgets);
    await tester.scrollUntilVisible(toKakomon.first, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 1);
    await shot(tester, 'l01_home');
    await tester.tap(toKakomon.first);
    await settle(tester, 4);

    // 章の過去問で1問答えると「この論点を先生と学ぶ」
    await tester.tap(find.text('○ 正しい').first);
    await settle(tester, 3);
    expect(find.text('この論点を先生と学ぶ'), findsOneWidget);
    await shot(tester, 'l02_answered');
    // Pro でない人には下にバナーがあるので、隠れていれば見えるところまで動かす
    await tester.ensureVisible(find.text('この論点を先生と学ぶ'));
    await settle(tester, 1);
    await tester.tap(find.text('この論点を先生と学ぶ'));
    await settle(tester, 8);

    // 会話でその論点の説明が始まる。上に「過去問」、候補に「この論点の過去問」
    expect(find.textContaining('を教えて'), findsWidgets);
    expect(find.text('過去問'), findsWidgets);
    final chip = find.textContaining('過去問 ').last;
    expect(find.textContaining('過去問 '), findsWidgets);
    await shot(tester, 'l03_learn');
    await tester.tap(chip);
    await settle(tester, 4);

    // 論点だけの過去問。同じ章の会話から来たので「先生と学ぶ」は出さず、戻るボタンで会話に戻る
    await tester.tap(find.text('○ 正しい').first);
    await settle(tester, 3);
    expect(find.text('この論点を先生と学ぶ'), findsNothing);
    await shot(tester, 'l04_point_set');
    await tester.pageBack();
    await settle(tester, 3);
    expect(find.byType(TextField), findsOneWidget, reason: '会話に戻った');
    await shot(tester, 'l05_back_in_chat');

    // 会話 → 学ぶ → 過去問のタブ（章ごと）
    await tester.pageBack();
    await settle(tester, 2);
    await tester.pageBack();
    await settle(tester, 2);
    await tester.tap(find.text('過去問').last);
    await settle(tester, 3);
    expect(find.text('章ごと'), findsOneWidget);
    await shot(tester, 'l06_kakomon_tab');
    expect(tester.takeException(), isNull);
  });
}
