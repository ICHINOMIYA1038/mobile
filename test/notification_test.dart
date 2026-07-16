import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/notification_service.dart';
import 'package:takken_simple/data/progress_repository.dart';
import 'package:takken_simple/data/question_repository.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/models/question.dart';
import 'package:takken_simple/models/review_state.dart';

/// 通知サービスの代役。実際に予約せず、何を呼ばれたかだけ記録する。
///
/// flutter_local_notifications は端末側の実装に依存するため、テストでは動かない。
/// ここで見たいのは「いつ・何件で鳴らすと判断したか」というアプリ側の判断なので、
/// 呼び出しの記録で十分。
class _FakeNotifications implements NotificationService {
  final List<String> calls = [];
  bool permissionGranted = true;
  Map<String, ReviewState> lastStates = {};
  List<Question> lastQuestions = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return permissionGranted;
  }

  @override
  Future<void> scheduleReviewReminders({
    required List<Question> questions,
    required Map<String, ReviewState> states,
    DateTime? now,
  }) async {
    calls.add('schedule');
    lastQuestions = questions;
    lastStates = states;
  }

  @override
  Future<void> cancelAll() async => calls.add('cancel');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('未対応: ${invocation.memberName}');
}

class _FakeQuestions implements QuestionRepository {
  @override
  Future<List<Question>> load() async => [
        for (var i = 0; i < 6; i++)
          Question(
            id: 'gyo-$i',
            category: '宅建業法',
            topic: '免許$i',
            statement: '記述$i',
            answer: true,
            explanation: '解説$i',
            reference: '宅建業法1条',
            difficulty: 1,
          ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotifications notifications;
  late StudyController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    notifications = _FakeNotifications();
    controller = StudyController(
      questions: _FakeQuestions(),
      progress: ProgressRepository(),
      notifications: notifications,
    );
    await controller.init();
    addTearDown(controller.dispose);
  });

  group('復習予定の組み直し', () {
    test('学習を終えると予定を組み直す', () async {
      controller.startSession();
      await controller.answer(controller.current!.answer);
      await controller.finishSession();

      expect(notifications.calls, contains('schedule'));
      // 実際の履歴を渡していること。空で呼ぶと通知が出ない。
      expect(notifications.lastStates, isNotEmpty);
      expect(notifications.lastQuestions, isNotEmpty);
    });

    test('履歴を消すと予約も消す（身に覚えのない通知を防ぐ）', () async {
      controller.startSession();
      await controller.answer(controller.current!.answer);
      await controller.resetProgress();

      expect(notifications.calls, contains('cancel'));
    });

    test('履歴を読み込むと、その内容に合わせて予定を組み直す', () async {
      controller.startSession();
      await controller.answer(controller.current!.answer);
      final exported = await controller.progressRepository.exportJson();
      await controller.resetProgress();
      notifications.calls.clear();

      await controller.importProgress(exported);
      expect(notifications.calls, contains('schedule'));
    });
  });

  group('通知の許可', () {
    test('初回だけ許可を求める', () async {
      final granted = await controller.maybeRequestNotificationPermission();
      expect(granted, isTrue);
      expect(notifications.calls.where((c) => c == 'request').length, 1);

      // 2回目以降は訊かない。iOS はダイアログを一度しか出せないため。
      notifications.calls.clear();
      final again = await controller.maybeRequestNotificationPermission();
      expect(again, isFalse);
      expect(notifications.calls, isNot(contains('request')));
    });

    test('訊いたことは再起動後も覚えている', () async {
      await controller.maybeRequestNotificationPermission();

      final revived = StudyController(
        questions: _FakeQuestions(),
        progress: ProgressRepository(),
        notifications: notifications,
      );
      await revived.init();
      addTearDown(revived.dispose);
      notifications.calls.clear();

      await revived.maybeRequestNotificationPermission();
      expect(notifications.calls, isNot(contains('request')));
    });

    test('許可されたらすぐ予定を組む', () async {
      await controller.maybeRequestNotificationPermission();
      expect(notifications.calls, contains('schedule'));
    });

    test('拒否されても予定は組まないが、落ちない', () async {
      notifications.permissionGranted = false;
      final granted = await controller.maybeRequestNotificationPermission();

      expect(granted, isFalse);
      expect(notifications.calls, isNot(contains('schedule')));
    });
  });

  group('何件と数えるか', () {
    // 通知の件数計算そのもの。ここを間違えると、用がないのに鳴ったり、
    // 逆に復習が溜まっているのに黙っていたりする。
    final now = DateTime(2026, 7, 16, 9);
    final service = NotificationService();

    List<Question> makeQuestions(int count) => [
          for (var i = 0; i < count; i++)
            Question(
              id: 'q$i',
              category: '宅建業法',
              topic: 't$i',
              statement: 's$i',
              answer: true,
              explanation: 'e$i',
              reference: 'r$i',
              difficulty: 1,
            ),
        ];

    ReviewState answered({required String id, required DateTime dueAt}) => ReviewState(
          questionId: id,
          repetition: 1,
          intervalDays: 1,
          dueAt: dueAt,
          lastAnsweredAt: now.subtract(const Duration(days: 1)),
          correctCount: 1,
        );

    test('未学習しかなければ0件（初日から毎晩鳴らさない）', () {
      final count = service.dueCountAt(
        questions: makeQuestions(300),
        states: {},
        at: now,
      );
      expect(count, 0);
    });

    test('期限が来た問題だけを数える', () {
      final questions = makeQuestions(4);
      final states = {
        // 期限切れ → 数える
        'q0': answered(id: 'q0', dueAt: now.subtract(const Duration(days: 2))),
        // ちょうど今 → 数える
        'q1': answered(id: 'q1', dueAt: now),
        // まだ先 → 数えない
        'q2': answered(id: 'q2', dueAt: now.add(const Duration(days: 3))),
        // 未学習 → 数えない（q3 は states に無い）
      };

      expect(service.dueCountAt(questions: questions, states: states, at: now), 2);
    });

    test('先の日付ほど件数が増える（期限が順に来るため）', () {
      final questions = makeQuestions(3);
      final states = {
        'q0': answered(id: 'q0', dueAt: now.add(const Duration(days: 1))),
        'q1': answered(id: 'q1', dueAt: now.add(const Duration(days: 3))),
        'q2': answered(id: 'q2', dueAt: now.add(const Duration(days: 5))),
      };

      expect(service.dueCountAt(questions: questions, states: states, at: now), 0);
      expect(
        service.dueCountAt(
          questions: questions,
          states: states,
          at: now.add(const Duration(days: 3)),
        ),
        2,
      );
      expect(
        service.dueCountAt(
          questions: questions,
          states: states,
          at: now.add(const Duration(days: 5)),
        ),
        3,
      );
    });

    test('全問を定着させて期限が先なら0件（静かになる）', () {
      final questions = makeQuestions(50);
      final states = {
        for (var i = 0; i < 50; i++)
          'q$i': ReviewState(
            questionId: 'q$i',
            repetition: 4,
            intervalDays: 30,
            dueAt: now.add(const Duration(days: 30)),
            lastAnsweredAt: now,
            correctCount: 4,
          ),
      };

      expect(service.dueCountAt(questions: questions, states: states, at: now), 0);
    });
  });
}
