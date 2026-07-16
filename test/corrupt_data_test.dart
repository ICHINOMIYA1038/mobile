import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/progress_repository.dart';
import 'package:takken_simple/data/question_repository.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/main.dart';
import 'package:takken_simple/models/question.dart';

/// 保存データが壊れていてもアプリが開くことを守るテスト。
///
/// 実際にあった不具合: SharedPreferences.getString() が try の外にあったため、
/// 保存値の型が想定外だと getString 自体が例外を投げ、init() が中断していた。
/// その結果 isLoading が true のまま固定され、読み込み中のスピナーから永久に戻れず、
/// 「学習履歴を消す」ボタンにも到達できないため復旧不能になっていた。
///
/// 既存アプリへの不満の筆頭が「アプリが落ちて学習データが消えた／開かない」であり、
/// ここで固まるのは最も避けたい壊れ方。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('壊れた保存データ', () {
    test('JSONとして壊れていても、履歴は空で読み込みは成功する', () async {
      SharedPreferences.setMockInitialValues({
        'review_states_v1': 'これはJSONではありません',
        'streak_v1': '{壊れている',
      });

      final repo = ProgressRepository();
      expect(await repo.loadStates(), isEmpty);
      expect((await repo.loadStreak()).current, 0);
    });

    test('保存値がString以外でも例外を投げない（getStringが投げるケース）', () async {
      // 保存形式が変わった場合や、古いバージョンに戻した場合に起こりうる。
      SharedPreferences.setMockInitialValues({
        'review_states_v1': 42,
        'streak_v1': true,
      });

      final repo = ProgressRepository();
      expect(await repo.loadStates(), isEmpty);
      expect((await repo.loadStreak()).current, 0);
    });

    test('JSONだが中身の形が違っても例外を投げない', () async {
      SharedPreferences.setMockInitialValues({
        // 期待は Map だが配列が入っている
        'review_states_v1': '[1, 2, 3]',
        // 期待するキーが無い
        'streak_v1': '{"unexpected": "shape"}',
      });

      final repo = ProgressRepository();
      expect(await repo.loadStates(), isEmpty);
      expect((await repo.loadStreak()).current, 0);
    });

    test('個々の問題の履歴が壊れていても、読み込み全体は落ちない', () async {
      SharedPreferences.setMockInitialValues({
        'review_states_v1': '{"gyo-001": {"questionId": "gyo-001", "repetition": "数値ではない"}}',
      });

      final repo = ProgressRepository();
      expect(await repo.loadStates(), isEmpty);
    });
  });

  group('壊れたデータでの起動', () {
    test('init は読み込み中のまま固まらない', () async {
      SharedPreferences.setMockInitialValues({'review_states_v1': 42});

      final controller = StudyController();
      await controller.init();

      // ここが true のままだと、ユーザーはスピナーから永久に戻れない。
      expect(controller.isLoading, isFalse);
      expect(controller.totalQuestions, greaterThan(0));
      addTearDown(controller.dispose);
    });

    testWidgets('壊れたデータでもホーム画面に到達して学習を始められる', (tester) async {
      SharedPreferences.setMockInitialValues({
        'review_states_v1': 42,
        'streak_v1': 'ゴミ',
      });

      final controller = StudyController();
      await tester.runAsync(controller.init);
      await tester.pumpWidget(TakkenApp(controller: controller));
      await tester.pumpAndSettle();
      addTearDown(controller.dispose);

      // スピナーではなくホームが出ること。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('学習をはじめる'), findsOneWidget);

      await tester.tap(find.text('学習をはじめる'));
      await tester.pumpAndSettle();
      expect(find.text('○'), findsOneWidget);
    });
  });

  group('問題データが読めない場合', () {
    testWidgets('スピナーで固まらず、理由と逃げ道を出す', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final controller = StudyController(questions: _BrokenQuestionRepository());
      await tester.runAsync(controller.init);
      await tester.pumpWidget(TakkenApp(controller: controller));
      await tester.pumpAndSettle();
      addTearDown(controller.dispose);

      expect(controller.loadFailed, isTrue);
      expect(controller.isLoading, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.text('問題を読み込めませんでした'), findsOneWidget);
      // 復旧の手段が必ず画面上にあること。
      expect(find.text('再試行'), findsOneWidget);
      expect(find.text('学習履歴を消してやり直す'), findsOneWidget);
    });
  });
}

/// 問題データの読み込みが失敗する状況を作る。
class _BrokenQuestionRepository implements QuestionRepository {
  @override
  Future<List<Question>> load() async => throw Exception('assets を読めない');
}
