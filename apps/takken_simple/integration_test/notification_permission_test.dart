import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/notification_service.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/models/question.dart';
import 'package:takken_simple/models/review_state.dart';

/// 端末（シミュレータ）でしか確かめられない部分を見る。
///
///   flutter test integration_test/notification_permission_test.dart -d 端末のUDID
///
/// 単体テストでは flutter_local_notifications の端末側実装が動かないため、
/// 「プラグインを呼んで落ちないか」「予約が実際に登録できるか」はここでしか分からない。
///
/// **requestPermission() はここでは呼ばない。**
/// iOS の許可ダイアログはユーザーが答えるまで返らず、自動テストからは閉じられないため、
/// 呼ぶとテストが固まる（実際に踏んだ）。
/// アプリ本体は addPostFrameCallback の中で待つので画面は固まらない。
/// 許可ダイアログの見え方は手で確認すること。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('端末上で復習の予約が実際に登録できる', (tester) async {
    final service = NotificationService();
    final now = DateTime.now();

    final questions = makeQuestions(3);
    // 全問が期限切れ＝毎晩お知らせが出る状態を作る。
    final states = {
      for (var i = 0; i < 3; i++)
        'q$i': ReviewState(
          questionId: 'q$i',
          repetition: 1,
          intervalDays: 1,
          dueAt: now.subtract(const Duration(days: 1)),
          lastAnsweredAt: now.subtract(const Duration(days: 2)),
          correctCount: 1,
        ),
    };

    // 予約時刻(20時)が確実に未来になるよう、基準を前日の朝に置く。
    final base = DateTime(now.year, now.month, now.day - 1, 9);
    await service.scheduleReviewReminders(
      questions: questions,
      states: states,
      now: base,
    );

    // 例外が飛ばずにここまで来られれば、端末側の予約は成立している。
    await service.cancelAll();
  });

  testWidgets('実データ300問で予約を組んでも落ちない', (tester) async {
    // 300問 × 7日ぶんの判定を端末上で通す。
    final controller = StudyController();
    await controller.init();
    addTearDown(controller.dispose);

    expect(controller.totalQuestions, 300);

    controller.startSession();
    await controller.answer(controller.current!.answer);
    await controller.finishSession();

    // 履歴を消すと予約も消える。身に覚えのない通知を残さない。
    await controller.resetProgress();
  });
}
