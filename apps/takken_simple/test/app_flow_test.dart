import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/main.dart';
import 'package:takken_simple/ui/widgets/result_banner_ad.dart';

/// 実際のアプリを起動して画面を触る。ホーム → 出題 → 解説 → 結果 → 成績 の一周を確認する。
/// 問題データは本物の assets/questions.json を読む。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 起動して読み込み完了まで進める。
  ///
  /// 問題データの読み込みは実際のファイル I/O で、テストの疑似時計では進まない。
  /// pumpAndSettle だけだと読み込み中のスピナーが回り続けてタイムアウトするため、
  /// runAsync の中で先に初期化を済ませてから画面に差し込む。
  Future<StudyController> launch(WidgetTester tester) async {
    final controller = StudyController();
    await tester.runAsync(controller.init);

    await tester.pumpWidget(TakkenApp(controller: controller));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets('ホームから学習を始めて、答えて、結果まで到達できる', (tester) async {
    await launch(tester);

    // ホーム: 未学習なので5問セットを始められる。
    expect(find.text('シンプルに学ぶ宅建'), findsOneWidget);
    expect(find.text('5問はじめる'), findsOneWidget);
    expect(find.textContaining('配点の高い分野から自動で出題'), findsOneWidget);

    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    // 出題画面: ○と×の2択だけが出ている。
    expect(find.text('○'), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('正しい'), findsOneWidget);
    expect(find.text('誤り'), findsOneWidget);

    // ○を押すと解説が出る。
    await tester.tap(find.text('○'));
    await tester.pumpAndSettle();

    expect(find.textContaining('答えは'), findsOneWidget);
    expect(find.text('次の問題へ'), findsOneWidget);
    // 解説表示中は○×が消え、二重回答できない。
    expect(find.text('正しい'), findsNothing);

    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();
    expect(find.text('○'), findsOneWidget);

    // 2問目に回答して終了する。
    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 結果画面に2問ぶんの集計が出る。
    expect(find.text('おつかれさまでした'), findsOneWidget);
    expect(find.text('2問中'), findsOneWidget);

    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    expect(find.text('シンプルに学ぶ宅建'), findsOneWidget);
  });

  testWidgets('1問も解かずに閉じると結果画面を挟まずホームに戻る', (tester) async {
    await launch(tester);

    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('おつかれさまでした'), findsNothing);
    expect(find.text('5問はじめる'), findsOneWidget);
  });

  testWidgets('成績画面に合格ゲージと4科目すべてが並ぶ', (tester) async {
    await launch(tester);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('本試験の配点で換算した予想得点'), findsOneWidget);
    // 得点は RichText で「0.0 / 50点」と一続きに組んでいる。
    expect(
      find.textContaining('0.0 / 50点', findRichText: true),
      findsOneWidget,
    );
    // 合格ラインが目的地として示される。
    expect(find.text('合格ライン 36点'), findsOneWidget);
    expect(find.text('1問解くごとにバーが伸びます'), findsOneWidget);

    for (final label in ['宅建業法', '権利関係', '法令上の制限', '税その他']) {
      expect(find.text(label), findsOneWidget);
    }
    // 配点が併記され、どの科目が重いか分かる。
    expect(find.text('本試験20問'), findsOneWidget);
  });

  testWidgets('ホームから用語集を検索して詳細を開ける', (tester) async {
    await launch(tester);

    await tester.tap(find.byTooltip('重要用語集'));
    await tester.pumpAndSettle();
    expect(find.text('重要用語集'), findsOneWidget);
    expect(find.text('50語'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'レインズ');
    await tester.pumpAndSettle();
    expect(find.text('指定流通機構'), findsOneWidget);
    expect(find.text('1語'), findsOneWidget);

    await tester.tap(find.text('指定流通機構'));
    await tester.pumpAndSettle();
    expect(find.text('用語解説'), findsOneWidget);
    expect(find.textContaining('REINS', findRichText: true), findsOneWidget);
  });

  testWidgets('間違えた問題を成績から苦手問題として復習できる', (tester) async {
    final controller = await launch(tester);
    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(controller.current!.answer ? '×' : '○'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('苦手問題'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('正解し直していない問題が1問'), findsOneWidget);

    await tester.tap(find.text('苦手問題'));
    await tester.pumpAndSettle();
    expect(find.text('苦手問題を復習（1問）'), findsOneWidget);
    await tester.tap(find.text('苦手問題を復習（1問）'));
    await tester.pumpAndSettle();
    expect(find.text('○'), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
  });

  testWidgets('回答すると正答した問題数がホームに出る', (tester) async {
    final controller = await launch(tester);
    expect(find.textContaining('0 / ', findRichText: true), findsOneWidget);

    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    final isTrue = controller.current!.answer;
    await tester.tap(find.text(isTrue ? '○' : '×'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 / ', findRichText: true), findsOneWidget);
  });

  testWidgets('ホームと出題画面に広告・課金の導線が出ない', (tester) async {
    // 広告は結果画面のみという約束。学習動線の入口に金の話を出さない。
    // 配置そのものは test/no_ads_during_study_test.dart が構造的に検証している。
    await launch(tester);

    // ホームには問題文が出ないので、語句で見てよい。
    for (final banned in ['広告', 'PR', '無料版', 'アップグレード', 'プレミアム', '課金']) {
      expect(
        find.textContaining(banned),
        findsNothing,
        reason: 'ホームに "$banned" が出ています',
      );
    }
    expect(find.byType(ResultBannerAd), findsNothing);

    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    // 出題画面は語句で判定してはいけない。「広告に関する規制」の問題が引かれると
    // 問題文そのものに「広告」が含まれ、出題は正しいのにテストが落ちる（実際に落ちた）。
    // 出題はランダムなので、語句で見ると不安定なテストになる。広告ウィジェットの有無で判定する。
    expect(find.byType(ResultBannerAd), findsNothing, reason: '出題画面に広告が出ています');

    // 解説を表示した状態でも同じ。
    await tester.tap(find.text('○'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultBannerAd), findsNothing, reason: '解説画面に広告が出ています');
  });

  testWidgets('5問解くと自動で結果へ進める', (tester) async {
    final controller = await launch(tester);
    await tester.tap(find.text('5問はじめる'));
    await tester.pumpAndSettle();

    for (var i = 0; i < StudyController.sessionGoal; i++) {
      await tester.tap(find.text(controller.current!.answer ? '○' : '×'));
      await tester.pumpAndSettle();

      if (i < StudyController.sessionGoal - 1) {
        expect(find.text('次の問題へ'), findsOneWidget);
        await tester.tap(find.text('次の問題へ'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('結果を見る'), findsOneWidget);
    await tester.tap(find.text('結果を見る'));
    await tester.pumpAndSettle();
    expect(find.text('5問中'), findsOneWidget);
  });
}
