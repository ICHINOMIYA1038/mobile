import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/main.dart';

/// 狭い端末や大きい文字設定でレイアウトが壊れないことを見る。
/// はみ出すと Flutter が例外を投げるため、描画できた時点で合格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 画面サイズを指定して起動する。
  Future<void> launchAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final controller = StudyController();
    await tester.runAsync(controller.init);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: TakkenApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  // iPhone SE（現行で最も狭い部類）と、大きめの端末。
  const narrow = Size(375, 667);
  const wide = Size(430, 932);

  group('狭い画面', () {
    testWidgets('ホームが崩れない', (tester) async {
      await launchAt(tester, narrow);
      expect(find.text('5問はじめる'), findsOneWidget);
    });

    testWidgets('出題画面が崩れない（長い問題文でも）', (tester) async {
      await launchAt(tester, narrow);
      await tester.tap(find.text('5問はじめる'));
      await tester.pumpAndSettle();
      expect(find.text('○'), findsOneWidget);

      // 解説まで開く。問題文＋解説＋条文が縦に積まれる最も詰まった状態。
      await tester.tap(find.text('○'));
      await tester.pumpAndSettle();
      expect(find.text('次の問題へ'), findsOneWidget);
    });

    testWidgets('合格グラフが300マス並んでも崩れない', (tester) async {
      await launchAt(tester, narrow);
      await tester.tap(find.byIcon(Icons.bar_chart_rounded));
      await tester.pumpAndSettle();

      // 狭い幅では Wrap が折り返す。はみ出せばここまで来られない。
      expect(find.text('合格グラフ'), findsOneWidget);
      expect(find.text('合格ライン 36点'), findsOneWidget);
    });
  });

  group('文字を大きくした設定', () {
    testWidgets('狭い画面 × 文字1.6倍でもホームが崩れない', (tester) async {
      // main.dart で上限1.6倍にクランプしている。その上限で確認する。
      await launchAt(tester, narrow, textScale: 1.6);
      expect(find.text('5問はじめる'), findsOneWidget);
    });

    testWidgets('狭い画面 × 文字1.6倍でも解説まで読める', (tester) async {
      await launchAt(tester, narrow, textScale: 1.6);
      await tester.tap(find.text('5問はじめる'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('○'));
      await tester.pumpAndSettle();
      expect(find.text('次の問題へ'), findsOneWidget);
    });

    testWidgets('文字1.6倍でも合格グラフが描ける', (tester) async {
      await launchAt(tester, wide, textScale: 1.6);
      await tester.tap(find.byIcon(Icons.bar_chart_rounded));
      await tester.pumpAndSettle();
      expect(find.text('合格グラフ'), findsOneWidget);
    });
  });
}
