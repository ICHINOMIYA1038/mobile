import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:neko_chemistry/data/progress_repository.dart';
import 'package:neko_chemistry/logic/quiz_controller.dart';
import 'package:neko_chemistry/main.dart';
import 'package:neko_chemistry/ui/screens/quiz_screen.dart';

/// 非同期の読み込みが終わるまで一定間隔でpumpし続ける。
/// pumpAndSettleは猫の周回アニメーション(無限repeat)のせいで使えないための代替。
/// assets読み込みは実I/Oを伴うため、runAsyncで実時間を与えてから毎回pumpする。
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// ホーム画面はコンテンツが増えて既定のテストビューポートに収まりきらないため、
/// タップ前にスクロールして画面内に入れる(実機ではSingleChildScrollViewが
/// 普通にスクロールするだけで問題ない)。
Future<void> _tapAfterScroll(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  // shared_preferencesはモック値を与えないとテスト環境で永久に解決しない。
  // オンボーディングは既読扱いにして、多くのテストではホーム画面から始める。
  setUp(
    () => SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true}),
  );
  // rootBundleはプロセス内でキャッシュされるため、テスト間で持ち越されて
  // 2つ目以降のasset読み込みが解決しなくなることがある。毎回クリアする。
  tearDown(() => rootBundle.clear());

  testWidgets('初回起動時はオンボーディングが表示され、完了後は二度と表示されない', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('ようこそ!'), findsOneWidget);
    expect(find.text('高校化学'), findsNothing);

    // 最後のページまで「次へ」を押し進める。
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await _tapAfterScroll(tester, find.text('はじめる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('高校化学'), findsOneWidget);

    final seen = await ProgressRepository().hasSeenOnboarding();
    expect(seen, isTrue);
  });

  testWidgets('ホーム画面が表示され、ランダム挑戦→出題設定→クイズ画面と遷移する', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('高校化学'), findsOneWidget);
    expect(find.text('ランダムに挑戦'), findsOneWidget);
    expect(find.text('分野を選んで挑戦'), findsOneWidget);

    await _tapAfterScroll(tester, find.text('ランダムに挑戦'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('出題数'), findsOneWidget);

    await _tapAfterScroll(tester, find.text('はじめる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('猫と学ぶ高校化学'), findsOneWidget);
    expect(find.textContaining('問 / '), findsOneWidget);
  });

  testWidgets('回答してもオーバーフローせず、「つぎへ」を押すまで次の問題に進まない', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: QuizScreen(controller: QuizController())),
    );
    await tester.pump();
    await _pumpUntil(tester, find.text('第1問 / 100'));

    expect(find.text('第1問 / 100'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('choice_0')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('つぎへ'), findsOneWidget);

    // ボタンを押さない限りしばらく待っても進まないこと。
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('第1問 / 100'), findsOneWidget);

    await tester.tap(find.text('つぎへ'));
    await tester.pump();

    expect(find.text('第2問 / 100'), findsOneWidget);
    expect(find.text('第1問 / 100'), findsNothing);
  });

  testWidgets('出題数を選ぶとその件数だけ出題される', (WidgetTester tester) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();

    await _tapAfterScroll(tester, find.text('ランダムに挑戦'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // デフォルトの10問から15問に選び直す。
    await _tapAfterScroll(tester, find.text('15問'));
    await tester.pump();

    await _tapAfterScroll(tester, find.text('はじめる'));
    await tester.pump();
    await _pumpUntil(tester, find.textContaining('問 / '));

    expect(find.text('第1問 / 15'), findsOneWidget);
  });

  testWidgets('分野を選んで挑戦すると、選んだ単元だけ出題される', (WidgetTester tester) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();

    await _tapAfterScroll(tester, find.text('分野を選んで挑戦'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 全選択された状態から「全解除」して1単元だけ選び直す。
    await _tapAfterScroll(tester, find.text('全解除'));
    await tester.pump();
    await _tapAfterScroll(tester, find.text('有機化学'));
    await tester.pump();
    await _tapAfterScroll(tester, find.text('20問'));
    await tester.pump();

    await _tapAfterScroll(tester, find.text('はじめる'));
    await tester.pump();
    await _pumpUntil(tester, find.textContaining('問 / '));

    // 有機化学は6問しかないため、20問指定でも6問に収まる。
    expect(find.text('第1問 / 6'), findsOneWidget);
  });

  testWidgets('モバイルメニュー(ドロワー)から設定画面に遷移できる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(ListTile, '設定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(tester, find.text('復習リマインダー'));

    expect(find.text('復習リマインダー'), findsOneWidget);
    expect(find.text('学習データをリセット'), findsOneWidget);
  });
}
