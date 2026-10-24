import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neko_chemistry/data/progress_repository.dart';
import 'package:neko_chemistry/data/question_repository.dart';
import 'package:neko_chemistry/main.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 撮影方式（マーカーファイル → simctl io screenshot）は neta_gacha の
/// integration_test/screenshots_test.dart と同じ。理由はそちらのコメント参照。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 猫の周回アニメーションが無限に続くので pumpAndSettle は終わらない。
  // 決まった時間だけ描画を進める。
  Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await settle(tester);

    final dir = Directory.systemTemp;
    final request = File('${dir.path}/shot_$name.request');
    final done = File('${dir.path}/shot_$name.done');
    if (done.existsSync()) done.deleteSync();
    request.writeAsStringSync('go');

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 2週間ほど続けて解いた状態にする。進捗画面のグラフと、
  /// きせかえの解放（ストリーク・累計正解数が条件）を見せるため。
  Future<void> seedProgress() async {
    final repo = ProgressRepository();
    await repo.resetAll();
    await repo.markOnboardingSeen();
    final questions = await QuestionRepository().loadAll();
    final random = Random(7);
    final today = DateTime.now();
    for (var day = 13; day >= 0; day--) {
      final date = today.subtract(Duration(days: day));
      for (var i = 0; i < 12; i++) {
        final q = questions[random.nextInt(questions.length)];
        await repo.recordAnswer(
          questionId: q.id,
          unit: q.unit,
          correct: random.nextDouble() < 0.78,
          now: date,
        );
      }
      await repo.markStudiedToday(now: date);
    }
    final streak = await repo.loadStreak();
    await repo.checkMilestones(
      streak: streak,
      totalCorrect: await repo.loadTotalCorrect(),
    );
    await repo.selectAccessory(ProgressRepository.accessoryCrown);
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    await seedProgress();

    // 1枚目: ホーム。王冠をかぶった猫と出題モード。
    await tester.pumpWidget(const NekoChemistryApp());
    await settle(tester, 3000);
    await shoot(tester, '01_home');

    // ランダム出題 → はじめる
    await tap(tester, find.text('ランダムに挑戦'));
    await tap(tester, find.text('はじめる'));

    // 2枚目: 4択の問題。
    await shoot(tester, '02_quiz');

    // 正解を押す。選択肢は毎回シャッフルされるので、表示中の問題文から正解の文言を引く。
    final questions = await QuestionRepository().loadAll();
    final current = questions.firstWhere(
      (q) => find.text(q.question).evaluate().isNotEmpty,
    );
    await tap(tester, find.text(current.answer));
    // 解説が見えるところまでカードをスクロールする。
    await tester.ensureVisible(find.text(current.explanation));

    // 3枚目: 答え合わせと解説。
    await shoot(tester, '03_answer');

    // クイズを抜けてタブへ戻る（クイズ画面に戻るボタンは無いので直接閉じる）。
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);

    // 4枚目: 進捗（単元別の正答率・学習記録）。
    await tap(tester, find.text('進捗'));
    await shoot(tester, '04_progress');

    // 5枚目: きせかえ。
    await tap(tester, find.text('きせかえ'));
    await shoot(tester, '05_accessory');
  });
}
