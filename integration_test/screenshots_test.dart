import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/purchase_repository.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/main.dart';

/// ストア掲載用のスクリーンショットを撮る。
///
///   ./tool/screenshots.sh
///
/// 実行すると screenshots/ に書き出される。撮り直しが要るたびに手作業で撮ると、
/// 端末サイズごとに揃えるのが苦痛になり、更新もされなくなるため自動化している。
///
/// 学習が進んだ状態を作ってから撮る。まっさらな画面では合格グラフの良さが伝わらないため。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 掲載映えする学習状態を作る。実際に解いた場合と同じ形の履歴を書き込む。
  Future<void> seedProgress() async {
    final now = DateTime.now();
    final states = <String, dynamic>{};

    // 科目ごとに進み具合を変え、盤面に濃淡と弱点（赤）が出るようにする。
    const plan = {
      '宅建業法': 0.80,
      '権利関係': 0.55,
      '法令上の制限': 0.35,
      '税その他': 0.20,
    };

    final raw = await rootBundle.loadString('assets/questions.json');
    final questions = (jsonDecode(raw) as Map<String, dynamic>)['questions'] as List<dynamic>;

    final byCategory = <String, List<String>>{};
    for (final q in questions) {
      final map = q as Map<String, dynamic>;
      byCategory.putIfAbsent(map['category'] as String, () => []).add(map['id'] as String);
    }

    plan.forEach((category, ratio) {
      final ids = byCategory[category]!;
      final count = (ids.length * ratio).round();
      for (var i = 0; i < count; i++) {
        // 定着・あと少し・学習中・要復習が混ざるように振り分ける。
        final bucket = i % 10;
        final (repetition, interval, correct, wrong) = switch (bucket) {
          0 => (0, 0, 1, 2),
          1 || 2 => (1, 1, 1, 0),
          3 || 4 => (2, 3, 2, 0),
          _ => (4, 30, 5, 0),
        };
        states[ids[i]] = {
          'questionId': ids[i],
          'repetition': repetition,
          'intervalDays': interval,
          'easeFactor': 2.5,
          'dueAt': now.add(Duration(days: interval)).toIso8601String(),
          'lastAnsweredAt': now.toIso8601String(),
          'correctCount': correct,
          'wrongCount': wrong,
        };
      }
    });

    SharedPreferences.setMockInitialValues({
      'review_states_v1': jsonEncode(states),
      'streak_v1': jsonEncode({
        'current': 12,
        'best': 21,
        'lastStudyDate': DateTime(now.year, now.month, now.day).toIso8601String(),
      }),
    });
  }

  Future<StudyController> launch(WidgetTester tester) async {
    final controller = StudyController();
    final purchases = PurchaseRepository();
    await controller.init();

    await tester.pumpWidget(TakkenApp(controller: controller, purchases: purchases));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    addTearDown(purchases.dispose);
    return controller;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets('ストア用スクリーンショット', (tester) async {
    await seedProgress();
    final controller = await launch(tester);

    // 1枚目: ホーム。「今日の復習」と「設定は要りません」が主役。
    await shoot(tester, '01_home');

    // 2枚目: 出題画面。○×の2択だけが並ぶ画面。
    // 学習済みデータを入れてあるので、ボタンは「学習をはじめる」ではなく「復習をはじめる」になる。
    await tester.tap(find.text('復習をはじめる'));
    await tester.pumpAndSettle();
    await shoot(tester, '02_quiz');

    // 3枚目: 解説。根拠条文まで出ることを見せる。
    final question = controller.current!;
    await tester.tap(find.text(question.answer ? '○' : '×'));
    await tester.pumpAndSettle();
    await shoot(tester, '03_explanation');

    // 4枚目: 成績画面の合格ゲージ。合格まであと何点かが分かる。
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    await shoot(tester, '04_pass_gauge');

    // 5枚目: 合格グラフ。差別化が一番伝わる画面なので、盤面が画面いっぱいに入る位置まで送る。
    await tester.scrollUntilVisible(
      find.text('合格グラフ'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await shoot(tester, '05_pass_graph');
  });
}
