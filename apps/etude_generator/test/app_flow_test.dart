import 'package:etude_generator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openGenerator(WidgetTester tester) async {
    await tester.pumpWidget(const EtudeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
  }

  Future<void> dismissRoleDrawIntro(WidgetTester tester) async {
    final button = find.text('わかりました');
    if (button.evaluate().isEmpty) return;
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('タイトル画面から生成画面へ進める', (tester) async {
    await tester.pumpWidget(const EtudeApp());
    await tester.pumpAndSettle();

    expect(find.text('エチュード\nメーカー'), findsOneWidget);
    expect(find.text('ÉTUDE'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('お題をつくる'), findsOneWidget);
  });

  testWidgets('条件を選んでお題を生成できる', (tester) async {
    await openGenerator(tester);

    expect(find.text('今日のエチュード'), findsOneWidget);
    expect(find.text('お題をつくる'), findsOneWidget);

    await tester.tap(find.text('3人'));
    await tester.tap(find.text('ミステリー'));
    await tester.tap(find.text('10分'));
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();

    expect(find.text('3人・ミステリー・10分'), findsOneWidget);
    for (final label in ['関係', '場所', '状況', '役', '秘密', '制約']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('生成したお題をお気に入りへ保存できる', (tester) async {
    await openGenerator(tester);
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('お気に入り'));
    await tester.pumpAndSettle();

    expect(find.text('お気に入り'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('このお題を実行する'), findsOneWidget);

    await tester.tap(find.text('このお題を実行する'));
    await tester.pumpAndSettle();
    expect(find.text('一人目の役を引く'), findsOneWidget);
  });

  testWidgets('役を一人ずつ引いて配役できる', (tester) async {
    await openGenerator(tester);
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();
    await dismissRoleDrawIntro(tester);

    expect(find.text('一人目の方へ'), findsOneWidget);
    await tester.tap(find.text('一人目の役を引く'));
    await tester.pumpAndSettle();
    expect(find.text('あなたの役です'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('次の人へ'));
    await tester.tap(find.text('次の人へ'));
    await tester.pumpAndSettle();
    expect(find.text('二人目の方へ'), findsOneWidget);
    await tester.tap(find.text('二人目の役を引く'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('配役完了'));
    await tester.tap(find.text('配役完了'));
    await tester.pumpAndSettle();

    expect(find.text('配役が決まりました。'), findsOneWidget);
    expect(find.text('役をもう一度見返す'), findsOneWidget);
    expect(find.text('エチュードを始める'), findsOneWidget);

    await tester.ensureVisible(find.text('エチュードを始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('エチュードを始める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('実演中'), findsOneWidget);
    expect(find.text('一時停止'), findsOneWidget);

    await tester.tap(find.text('終了する'));
    await tester.pumpAndSettle();
    expect(find.text('振り返り'), findsOneWidget);
    expect(find.text('同じお題でもう一度'), findsOneWidget);
    expect(find.text('新しいお題を作る'), findsOneWidget);
  });

  testWidgets('お気に入りをジャンルで絞り込める', (tester) async {
    await openGenerator(tester);

    // 日常のお題を1件お気に入りにする。
    await tester.tap(find.text('日常'));
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();

    // ミステリーのお題をもう1件お気に入りにする。
    // 直前の ensureVisible でジャンル選択チップが画面外に押し出されている
    // ため、いったん一番上までスクロールし直してから選び直す。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ミステリー'));
    await tester.tap(find.text('もう一度'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('お気に入りに追加'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('お気に入り'));
    await tester.pumpAndSettle();

    // 以降の finder は、下に隠れている生成画面のジャンル選択チップと
    // 名前が衝突しないよう、お気に入り画面の中だけを探す。
    Finder inFavorites(String text) => find.descendant(
      of: find.byType(FavoritesScreen),
      matching: find.text(text),
    );

    // 絞り込みチップが両方のジャンル分表示される。
    expect(inFavorites('すべて'), findsOneWidget);
    expect(inFavorites('日常'), findsOneWidget);
    expect(inFavorites('ミステリー'), findsOneWidget);
    expect(inFavorites('2人・日常・5分'), findsOneWidget);
    expect(inFavorites('2人・ミステリー・5分'), findsOneWidget);

    // 「ミステリー」を選ぶと日常の方は消える。
    await tester.tap(inFavorites('ミステリー'));
    await tester.pumpAndSettle();
    expect(inFavorites('2人・ミステリー・5分'), findsOneWidget);
    expect(inFavorites('2人・日常・5分'), findsNothing);

    // 「すべて」に戻すと両方また見える。
    await tester.tap(inFavorites('すべて'));
    await tester.pumpAndSettle();
    expect(inFavorites('2人・日常・5分'), findsOneWidget);
    expect(inFavorites('2人・ミステリー・5分'), findsOneWidget);
  });
}
