import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:takken_simple/logic/scheduler.dart';
import 'package:takken_simple/models/question.dart';
import 'package:takken_simple/models/review_state.dart';

Question q(String id, String category) => Question(
      id: id,
      category: category,
      topic: 'テスト',
      statement: 'テスト用の記述',
      answer: true,
      explanation: '解説',
      reference: '宅建業法1条',
      difficulty: 1,
    );

void main() {
  final now = DateTime(2026, 7, 15, 9);

  group('grade', () {
    test('正解を重ねると間隔が 1日 → 3日 → それ以上 と伸びる', () {
      final scheduler = Scheduler();
      var state = const ReviewState(questionId: 'a');

      state = scheduler.grade(state: state, isCorrect: true, now: now);
      expect(state.intervalDays, 1);
      expect(state.repetition, 1);
      expect(state.dueAt, now.add(const Duration(days: 1)));

      state = scheduler.grade(state: state, isCorrect: true, now: now);
      expect(state.intervalDays, 3);

      state = scheduler.grade(state: state, isCorrect: true, now: now);
      expect(state.intervalDays, greaterThan(3));
      expect(state.correctCount, 3);
    });

    test('間違えると連続正解がリセットされ、同じセッション中に再出題される', () {
      final scheduler = Scheduler();
      var state = const ReviewState(questionId: 'a');

      state = scheduler.grade(state: state, isCorrect: true, now: now);
      state = scheduler.grade(state: state, isCorrect: true, now: now);
      expect(state.repetition, 2);

      state = scheduler.grade(state: state, isCorrect: false, now: now);
      expect(state.repetition, 0);
      expect(state.intervalDays, 0);
      expect(state.wrongCount, 1);
      // 10分後には復習対象に戻る。
      expect(state.isDue(now.add(const Duration(minutes: 11))), isTrue);
      expect(state.isDue(now), isFalse);
    });

    test('間違えるほど ease が下がるが、下限 1.3 を割らない', () {
      final scheduler = Scheduler();
      var state = const ReviewState(questionId: 'a');

      for (var i = 0; i < 20; i++) {
        state = scheduler.grade(state: state, isCorrect: false, now: now);
      }
      expect(state.easeFactor, 1.3);
    });

    test('正解を重ねても ease が上限 2.8 を超えない', () {
      final scheduler = Scheduler();
      var state = const ReviewState(questionId: 'a');

      for (var i = 0; i < 20; i++) {
        state = scheduler.grade(state: state, isCorrect: true, now: now);
      }
      expect(state.easeFactor, lessThanOrEqualTo(2.8));
    });

    test('正解を重ね続けても間隔は1年で頭打ちになり、日付が破綻しない', () {
      // 間隔は ease 倍ずつ伸びるため、上限がないと DateTime の範囲を超えてクラッシュする。
      final scheduler = Scheduler();
      var state = const ReviewState(questionId: 'a');

      for (var i = 0; i < 100; i++) {
        state = scheduler.grade(state: state, isCorrect: true, now: now);
      }
      expect(state.intervalDays, 365);
      expect(state.dueAt, now.add(const Duration(days: 365)));
    });
  });

  group('pickNext', () {
    test('未学習が多数あるとき、出題は本試験の配点比率におおむね沿う', () {
      // 各科目を同数用意しても、宅建業法が最も多く出るはず。
      final questions = <Question>[
        for (var i = 0; i < 25; i++) q('gyo-$i', '宅建業法'),
        for (var i = 0; i < 25; i++) q('ken-$i', '権利関係'),
        for (var i = 0; i < 25; i++) q('hor-$i', '法令上の制限'),
        for (var i = 0; i < 25; i++) q('zei-$i', '税その他'),
      ];
      final scheduler = Scheduler(random: Random(42));
      final counts = <String, int>{};

      for (var i = 0; i < 4000; i++) {
        final picked = scheduler.pickNext(
          questions: questions,
          states: {},
          now: now,
        )!;
        counts.update(picked.category, (v) => v + 1, ifAbsent: () => 1);
      }

      final gyoho = counts['宅建業法']!;
      final kenri = counts['権利関係']!;
      final zei = counts['税その他']!;

      // 配点は 20:14:8:8。宅建業法は税その他の約2.5倍出る想定（±20%で許容）。
      expect(gyoho / zei, closeTo(2.5, 0.5));
      expect(gyoho / kenri, closeTo(20 / 14, 0.3));
      expect(gyoho, greaterThan(kenri));
      expect(kenri, greaterThan(zei));
    });

    test('復習期限が来た問題は、期限が来ていない問題より優先される', () {
      final questions = [q('due', '宅建業法'), q('notdue', '宅建業法')];
      final states = {
        'due': ReviewState(
          questionId: 'due',
          repetition: 1,
          intervalDays: 1,
          dueAt: now.subtract(const Duration(days: 2)),
          lastAnsweredAt: now.subtract(const Duration(days: 3)),
          correctCount: 1,
        ),
        'notdue': ReviewState(
          questionId: 'notdue',
          repetition: 1,
          intervalDays: 10,
          dueAt: now.add(const Duration(days: 10)),
          lastAnsweredAt: now,
          correctCount: 1,
        ),
      };

      final scheduler = Scheduler(random: Random(1));
      for (var i = 0; i < 50; i++) {
        final picked = scheduler.pickNext(
          questions: questions,
          states: states,
          now: now,
        );
        expect(picked!.id, 'due');
      }
    });

    test('全問が復習待ちでも、先取り演習として出題を続ける', () {
      final questions = [q('a', '宅建業法')];
      final states = {
        'a': ReviewState(
          questionId: 'a',
          repetition: 3,
          intervalDays: 30,
          dueAt: now.add(const Duration(days: 30)),
          lastAnsweredAt: now,
          correctCount: 3,
        ),
      };

      final picked = Scheduler(random: Random(1)).pickNext(
        questions: questions,
        states: states,
        now: now,
      );
      expect(picked, isNotNull);
    });

    test('候補が複数あれば直前と同じ問題を連続で出さない', () {
      final questions = [q('a', '宅建業法'), q('b', '宅建業法')];
      final scheduler = Scheduler(random: Random(7));

      for (var i = 0; i < 50; i++) {
        final picked = scheduler.pickNext(
          questions: questions,
          states: {},
          now: now,
          excludeId: 'a',
        );
        expect(picked!.id, 'b');
      }
    });

    test('問題が1問しかなければ、直前と同じでもその1問を出す', () {
      final picked = Scheduler(random: Random(3)).pickNext(
        questions: [q('a', '宅建業法')],
        states: {},
        now: now,
        excludeId: 'a',
      );
      expect(picked!.id, 'a');
    });

    test('問題が空なら null を返す', () {
      final picked = Scheduler().pickNext(questions: [], states: {}, now: now);
      expect(picked, isNull);
    });

    test('苦手な問題（ease が低い）ほど多く出る', () {
      final questions = [q('hard', '宅建業法'), q('easy', '宅建業法')];
      final states = {
        'hard': ReviewState(
          questionId: 'hard',
          easeFactor: 1.3,
          dueAt: now.subtract(const Duration(days: 1)),
          lastAnsweredAt: now.subtract(const Duration(days: 2)),
        ),
        'easy': ReviewState(
          questionId: 'easy',
          easeFactor: 2.8,
          dueAt: now.subtract(const Duration(days: 1)),
          lastAnsweredAt: now.subtract(const Duration(days: 2)),
        ),
      };

      final scheduler = Scheduler(random: Random(11));
      var hard = 0;
      for (var i = 0; i < 1000; i++) {
        final picked = scheduler.pickNext(
          questions: questions,
          states: states,
          now: now,
        )!;
        if (picked.id == 'hard') hard++;
      }
      expect(hard, greaterThan(600));
    });
  });

  group('ReviewState', () {
    test('3連続正解かつ間隔21日以上で「定着」とみなす', () {
      const notYet = ReviewState(questionId: 'a', repetition: 3, intervalDays: 20);
      expect(notYet.isMastered, isFalse);

      const mastered = ReviewState(questionId: 'a', repetition: 3, intervalDays: 21);
      expect(mastered.isMastered, isTrue);
    });

    test('未学習の問題は常に出題対象', () {
      const state = ReviewState(questionId: 'a');
      expect(state.isNew, isTrue);
      expect(state.isDue(now), isTrue);
    });
  });
}
