import 'package:flutter_test/flutter_test.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/models/review_state.dart';

void main() {
  final now = DateTime(2026, 7, 16, 9);

  group('マス目の濃さ', () {
    test('未学習は untouched', () {
      const state = ReviewState(questionId: 'a');
      expect(state.masteryLevel, MasteryLevel.untouched);
    });

    test('間違えた問題は needsReview（連続正解が0に戻るため）', () {
      const state = ReviewState(
        questionId: 'a',
        repetition: 0,
        wrongCount: 1,
      );
      final answered = state.copyWith(lastAnsweredAt: now);
      expect(answered.masteryLevel, MasteryLevel.needsReview);
    });

    test('1回正解で learning', () {
      final state = const ReviewState(questionId: 'a', repetition: 1)
          .copyWith(lastAnsweredAt: now);
      expect(state.masteryLevel, MasteryLevel.learning);
    });

    test('2回連続正解で familiar', () {
      final state = const ReviewState(questionId: 'a', repetition: 2)
          .copyWith(lastAnsweredAt: now);
      expect(state.masteryLevel, MasteryLevel.familiar);
    });

    test('3連続正解でも間隔が短いうちは familiar のまま', () {
      final state =
          const ReviewState(questionId: 'a', repetition: 3, intervalDays: 8)
              .copyWith(lastAnsweredAt: now);
      expect(state.isMastered, isFalse);
      expect(state.masteryLevel, MasteryLevel.familiar);
    });

    test('定着すると mastered', () {
      final state =
          const ReviewState(questionId: 'a', repetition: 3, intervalDays: 21)
              .copyWith(lastAnsweredAt: now);
      expect(state.masteryLevel, MasteryLevel.mastered);
    });

    test('定着した問題を間違えると needsReview に落ちる', () {
      // 盤面が一度濃くなっても、間違えれば弱点として見えるようになる。
      final mastered =
          const ReviewState(questionId: 'a', repetition: 3, intervalDays: 21)
              .copyWith(lastAnsweredAt: now);
      expect(mastered.masteryLevel, MasteryLevel.mastered);

      final wrong = mastered.copyWith(repetition: 0, intervalDays: 0);
      expect(wrong.masteryLevel, MasteryLevel.needsReview);
    });
  });

  group('合格ライン', () {
    test('目安は36点', () {
      expect(StudyController.passingScore, 36.0);
    });
  });
}
