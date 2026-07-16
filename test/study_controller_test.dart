import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/progress_repository.dart';
import 'package:takken_simple/data/question_repository.dart';
import 'package:takken_simple/logic/scheduler.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/models/question.dart';

/// アセットを読まずに固定の問題を返すリポジトリ。
class _FakeQuestionRepository implements QuestionRepository {
  @override
  Future<List<Question>> load() async => [
        for (var i = 0; i < 10; i++)
          Question(
            id: 'gyo-$i',
            category: '宅建業法',
            topic: '免許$i',
            statement: '記述$i',
            answer: i.isEven,
            explanation: '解説$i',
            reference: '宅建業法1条',
            difficulty: 1,
          ),
        for (var i = 0; i < 7; i++)
          Question(
            id: 'ken-$i',
            category: '権利関係',
            topic: '意思表示$i',
            statement: '記述$i',
            answer: true,
            explanation: '解説$i',
            reference: '民法1条',
            difficulty: 2,
          ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudyController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = StudyController(
      questions: _FakeQuestionRepository(),
      progress: ProgressRepository(),
      scheduler: Scheduler(random: Random(5)),
    );
    await controller.init();
  });

  test('起動直後は全問が未学習で、復習は0問', () {
    expect(controller.isLoading, isFalse);
    expect(controller.totalQuestions, 17);
    expect(controller.newCount, 17);
    expect(controller.dueCount, 0);
    expect(controller.answeredCount, 0);
  });

  test('セッションを始めると問題が出る', () {
    controller.startSession();
    expect(controller.current, isNotNull);
    expect(controller.result, isNull);
  });

  test('正解すると結果が出て、次へ進める', () async {
    controller.startSession();
    final question = controller.current!;

    await controller.answer(question.answer);

    final result = controller.result!;
    expect(result.isCorrect, isTrue);
    expect(controller.session.length, 1);
    expect(controller.answeredCount, 1);

    controller.next();
    expect(controller.result, isNull);
    expect(controller.current, isNotNull);
  });

  test('不正解も記録され、正答率に反映される', () async {
    controller.startSession();
    final question = controller.current!;

    await controller.answer(!question.answer);

    expect(controller.result!.isCorrect, isFalse);
    expect(controller.overallAccuracy, 0);
  });

  test('解説の表示中は二重回答を受け付けない', () async {
    controller.startSession();
    final question = controller.current!;

    await controller.answer(question.answer);
    await controller.answer(!question.answer);

    // 2回目は無視され、セッションにも記録されない。
    expect(controller.session.length, 1);
    expect(controller.result!.isCorrect, isTrue);
  });

  test('回答すると連続学習日数が1日目になる', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);
    expect(controller.streak.current, 1);
  });

  test('回答は即座に保存され、再起動しても残る', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);

    final revived = StudyController(
      questions: _FakeQuestionRepository(),
      progress: ProgressRepository(),
    );
    await revived.init();

    expect(revived.answeredCount, 1);
    expect(revived.streak.current, 1);
  });

  test('1問正解しただけでは、その科目の配点を満額計上しない', () async {
    // 宅建業法を1問正解した時点で「20点取れる」と表示するのは実態と懸け離れており、
    // 学習者に誤った安心を与えるため、未回答は0点として扱う。
    controller.startSession();
    await controller.answer(controller.current!.answer);

    expect(controller.answeredCount, 1);
    // 宅建業法なら 配点20 × (1問/10問) = 2.0点、権利関係なら 配点14 × (1問/7問) = 2.0点。
    // 修正前はどちらも科目の配点を満額（20点や14点）計上していた。
    expect(controller.predictedScore, closeTo(2.0, 0.001));
  });

  test('未回答の科目は0点として扱われる', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);

    for (final stats in controller.categoryStats) {
      if (stats.answered == 0) expect(stats.scoreRatio, 0);
    }
  });

  test('正答率は回答済みの中での割合を示し、未回答に引きずられない', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);

    final answeredStats =
        controller.categoryStats.firstWhere((s) => s.answered > 0);
    // 1問だけ正解 → その科目の正答率は100%、ただし得点換算は満額にならない。
    expect(answeredStats.accuracy, 1.0);
    expect(answeredStats.scoreRatio, lessThan(1.0));
  });

  test('全問正解すると、その科目の配点を満額計上する', () async {
    controller.startSession();
    // 未学習がなくなるまで解き続ける。
    for (var i = 0; i < 500 && controller.newCount > 0; i++) {
      await controller.answer(controller.current!.answer);
      controller.next();
    }

    expect(controller.newCount, 0);
    for (final stats in controller.categoryStats) {
      if (stats.total > 0) {
        expect(stats.accuracy, 1.0);
        expect(stats.scoreRatio, 1.0);
      }
    }

    // このテスト用の問題は宅建業法(配点20)と権利関係(配点14)のみ。
    expect(controller.predictedScore, closeTo(34.0, 0.001));
  });

  test('全問不正解なら予想得点は0点', () async {
    controller.startSession();
    for (var i = 0; i < 30; i++) {
      final q = controller.current;
      if (q == null) break;
      await controller.answer(!q.answer);
      controller.next();
    }
    expect(controller.predictedScore, 0);
  });

  test('間違えた問題は10分後に復習対象として戻ってくる', () async {
    controller.startSession();
    await controller.answer(!controller.current!.answer);

    // 直後は再出題されない（10分後に due）。
    expect(controller.dueCount, 0);
  });

  test('履歴を消すと未学習の状態に戻る', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);
    expect(controller.answeredCount, 1);

    await controller.resetProgress();

    expect(controller.answeredCount, 0);
    expect(controller.newCount, 17);
    expect(controller.streak.current, 0);
    expect(controller.session, isEmpty);
  });

  test('書き出したデータを読み込むと履歴が復元される', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);
    final exported = await controller.progressRepository.exportJson();

    await controller.resetProgress();
    expect(controller.answeredCount, 0);

    final ok = await controller.importProgress(exported);
    expect(ok, isTrue);
    expect(controller.answeredCount, 1);
    expect(controller.streak.current, 1);
  });

  test('壊れたデータを読み込んでも失敗を返すだけで、既存の履歴は消えない', () async {
    controller.startSession();
    await controller.answer(controller.current!.answer);

    final ok = await controller.importProgress('これはJSONではありません');

    expect(ok, isFalse);
    expect(controller.answeredCount, 1);
  });
}
