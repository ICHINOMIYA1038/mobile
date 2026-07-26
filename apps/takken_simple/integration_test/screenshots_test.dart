import 'dart:convert';
import 'dart:io';

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
///
/// 撮影方法について: `binding.takeScreenshot()` は使わない。
/// iOS + Impeller ではこの API が実際の描画内容を無視して単色の背景しか返さない
/// 不具合があるうえ、`flutter drive` の拡張ドライバは screenshot をテスト完了後に
/// まとめて回収する仕組みのため、各ショットのタイミングと画面遷移が一致しない
/// （全ショットが最後の画面になる）。そこで、シミュレータの tmp
/// ディレクトリ（ホストからも同じパスで見える）にマーカーファイルを置き、
/// `tool/screenshots.sh` 側の常駐プロセスが `xcrun simctl io screenshot` で
/// 実画面をそのタイミングで撮る方式にしている。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 掲載映えする学習状態を作る。実際に解いた場合と同じ形の履歴を書き込む。
  Future<void> seedProgress() async {
    final now = DateTime.now();
    final states = <String, dynamic>{};

    // 科目ごとに進み具合を変え、盤面に濃淡と弱点（赤）が出るようにする。
    const plan = {'宅建業法': 0.80, '権利関係': 0.55, '法令上の制限': 0.35, '税その他': 0.20};

    final raw = await rootBundle.loadString('assets/questions.json');
    final questions =
        (jsonDecode(raw) as Map<String, dynamic>)['questions'] as List<dynamic>;

    final byCategory = <String, List<String>>{};
    for (final q in questions) {
      final map = q as Map<String, dynamic>;
      byCategory
          .putIfAbsent(map['category'] as String, () => [])
          .add(map['id'] as String);
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

    // このテストは flutter drive で実機/シミュレータ上のアプリとして動くため、
    // setMockInitialValues（テストバインディング内のみ有効なモック）ではなく、
    // 実際に使われる SharedPreferences に書き込む。モックのままだと
    // 「訊き済み」が実機側に反映されず、通知許可の実ダイアログが出て撮影の邪魔になる。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('review_states_v1', jsonEncode(states));
    await prefs.setString(
      'streak_v1',
      jsonEncode({
        'current': 12,
        'best': 21,
        'lastStudyDate': DateTime(
          now.year,
          now.month,
          now.day,
        ).toIso8601String(),
      }),
    );
    // 通知の許可ダイアログは撮影の邪魔になるうえ、システムダイアログは
    // テストから閉じられず不安定の元になる。「訊き済み」にして出さない。
    await prefs.setBool('asked_notification_v1', true);
    // ストアの評価ダイアログは撮影画像に含めない。
    await prefs.setBool('review_requested_v1', true);
  }

  Future<StudyController> launch(WidgetTester tester) async {
    final controller = StudyController();
    final purchases = PurchaseRepository();
    await controller.init();

    await tester.pumpWidget(
      TakkenApp(controller: controller, purchases: purchases),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    addTearDown(purchases.dispose);
    return controller;
  }

  /// `tool/screenshots.sh` の常駐プロセスへ、今の画面を撮るよう頼む。
  ///
  /// システムの tmp ディレクトリはシミュレータでもホスト側から同じパスで
  /// 見えるため、マーカーファイルの置き場所として使える。相手が
  /// `<name>.request` を見つけて `xcrun simctl io screenshot` を実行し、
  /// `<name>.done` を置いたら完了とみなす。応答がなければ最大5秒で諦める
  /// （手元で `flutter test` 単体を動かす場合など、常駐プロセスがいなくても
  /// テスト自体は失敗させない）。
  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();

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

  testWidgets('ストア用スクリーンショット', (tester) async {
    await seedProgress();
    final controller = await launch(tester);

    // 1枚目: ホーム。「今日の復習」と「設定は要りません」が主役。
    await shoot(tester, '01_home');

    // 2枚目: 出題画面。○×の2択だけが並ぶ画面。
    await tester.tap(find.text('今日の復習'));
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

    // IAP審査用: 商品の購入ボタンと「購入を復元する」が同時に見える画面。
    // ストア掲載用ではなく、App Store Connect のIAP「審査情報」に添付する。
    await tester.scrollUntilVisible(
      find.text('購入を復元する'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await shoot(tester, 'iap_review');
  });
}
