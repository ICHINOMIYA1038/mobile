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
    await _pumpUntil(tester, find.textContaining('問 / '));

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
    await _pumpUntil(tester, find.text('第1問 / 510'));

    expect(find.text('第1問 / 510'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('choice_0')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('つぎへ'), findsOneWidget);

    // ボタンを押さない限りしばらく待っても進まないこと。
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('第1問 / 510'), findsOneWidget);

    await tester.tap(find.text('つぎへ'));
    await tester.pump();

    expect(find.text('第2問 / 510'), findsOneWidget);
    expect(find.text('第1問 / 510'), findsNothing);
  });

  testWidgets('★でブックマークした問題は、ブックマーク復習モードでだけ出題される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(controller: QuizController(questionCount: 1)),
      ),
    );
    await tester.pump();
    await _pumpUntil(tester, find.text('第1問 / 1'));

    final bookmarkButton = find.byKey(const ValueKey('bookmark_button'));
    expect(bookmarkButton, findsOneWidget);
    await tester.tap(bookmarkButton);
    await tester.pump();

    final bookmarkIds = await ProgressRepository().loadBookmarkedQuestionIds();
    expect(bookmarkIds.length, 1);

    await tester.pumpWidget(
      MaterialApp(
        // 1つ前のQuizScreenと同じ位置に別のQuizScreenを積むと、Flutterが同じ
        // Stateを使い回してinitStateを呼び直さないため、別Keyで確実に張り替える。
        home: QuizScreen(
          key: UniqueKey(),
          controller: QuizController(bookmarkOnly: true),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntil(tester, find.textContaining('問 / '));

    expect(find.text('第1問 / 1'), findsOneWidget);
  });

  testWidgets('出題数を選ぶとその件数だけ出題される', (WidgetTester tester) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
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

    expect(find.text('第1問 / 20'), findsOneWidget);
  });

  testWidgets('フッターの常時ナビゲーションから設定画面に遷移できる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '設定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(tester, find.text('復習リマインダー'));

    expect(find.text('復習リマインダー'), findsOneWidget);
    expect(find.text('学習データをリセット'), findsOneWidget);
  });

  testWidgets('進捗画面に学習カレンダーと実績バッジのセクションが表示される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '進捗'));
    await tester.pump();
    await _pumpUntil(tester, find.text('累計回答'));

    // ListViewは画面外のウィジェットを遅延構築するため、スクロールしながら探す。
    await tester.dragUntilVisible(
      find.text('学習カレンダー'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('学習カレンダー'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('実績バッジ'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('実績バッジ'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('猫のきせかえ'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('猫のきせかえ'), findsOneWidget);
  });

  testWidgets('進捗画面にまだ十分なデータがないときは猫タイプ診断が「診断できません」表示になる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '進捗'));
    await tester.pump();
    await _pumpUntil(tester, find.text('累計回答'));

    await tester.dragUntilVisible(
      find.textContaining('猫タイプ診断'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.textContaining('5問以上解くと診断できます'), findsOneWidget);

    // 学習記録シェアカードのボタンも表示されていること。
    await tester.dragUntilVisible(
      find.text('学習記録をシェア'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('学習記録をシェア'), findsOneWidget);
  });

  testWidgets('設定画面で通知時刻を選ぶ項目が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '設定'));
    await tester.pump();
    await _pumpUntil(tester, find.text('通知時刻'));

    expect(find.text('通知時刻'), findsOneWidget);
  });

  testWidgets('暗記カードで「覚えた」を押すと次のカードに進み、記録が保存される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '用語集'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('暗記カード'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 21'), findsOneWidget);

    await tester.tap(find.text('覚えた'));
    await tester.pump();

    expect(find.text('2 / 21'), findsOneWidget);
    expect(find.text('覚えた: 1'), findsOneWidget);

    final known = await ProgressRepository().loadKnownTerms();
    expect(known.length, 1);
  });

  testWidgets('用語集の元素周期表タブから元素の詳細が見られる', (WidgetTester tester) async {
    await tester.pumpWidget(const NekoChemistryApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(NavigationDestination, '用語集'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('元素周期表'));
    await tester.pumpAndSettle();

    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();

    expect(find.text('炭素'), findsOneWidget);
  });

  testWidgets('クイズを1問正解すると「はじめの一歩」と「満点クリア」バッジが解放される', (
    WidgetTester tester,
  ) async {
    // ResultScreenへの実際の画面遷移は結果演出用のTimerが残り続けテストの
    // 後始末と衝突するため、UIを介さずコントローラーを直接操作して検証する。
    final controller = QuizController(questionCount: 1);
    await tester.runAsync(() => controller.init());

    final correctIndex = controller.currentQuestion.answerIndex;
    controller.selectAnswer(correctIndex);
    controller.nextQuestion();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    final badges = await ProgressRepository().loadUnlockedBadges();
    expect(badges, contains(ProgressRepository.badgeFirstStep));
    expect(badges, contains(ProgressRepository.badgePerfectClear));
  });
}
