import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neko_chemistry/data/notification_service.dart';
import 'package:neko_chemistry/data/progress_repository.dart';
import 'package:neko_chemistry/models/question.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('選択肢をシャッフルしても正解は同じ文になる', () {
    const q = Question(
      id: 'x',
      unit: 'u',
      question: '?',
      choices: ['a', 'b', 'c', 'd'],
      answerIndex: 1,
      explanation: 'e',
    );
    for (var i = 0; i < 20; i++) {
      final s = q.shuffled(Random(i));
      expect(s.answer, 'b');
      expect(s.choices.toSet(), q.choices.toSet());
    }
  });

  test('リマインダーは今日の時刻を過ぎていれば明日', () {
    final now = DateTime(2026, 9, 24, 20);
    expect(NotificationService.nextOccurrence(now, 19, 0), DateTime(2026, 9, 25, 19));
    expect(NotificationService.nextOccurrence(now, 21, 0), DateTime(2026, 9, 24, 21));
  });

  test('連続日数は2日以上空くと0として読み出す', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = ProgressRepository();
    await repo.markStudiedToday(now: DateTime(2026, 9, 10));
    await repo.markStudiedToday(now: DateTime(2026, 9, 11));
    expect((await repo.loadStreak(now: DateTime(2026, 9, 12))).current, 2);
    final lapsed = await repo.loadStreak(now: DateTime(2026, 9, 24));
    expect(lapsed.current, 0);
    expect(lapsed.best, 2);
  });

  test('回答とブックマークが同時でもどちらの記録も消えない', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = ProgressRepository();
    await Future.wait([
      repo.recordAnswer(questionId: 'q1', unit: 'u', correct: false),
      repo.toggleBookmark('q1'),
    ]);
    expect(await repo.loadWeakQuestionIds(), {'q1'});
    expect(await repo.loadBookmarkedQuestionIds(), {'q1'});
  });
}
