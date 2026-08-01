import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neta_maker/main.dart';
import 'package:neta_maker/models/maker_result.dart';

// MysticBackground の星空演出は `AnimationController.repeat()` で無限に
// アニメーションし続けるため、`pumpAndSettle()` は「保留中のフレームがなくなる
// まで待つ」性質上、永久にタイムアウトする。画面遷移(既定300ms)や結果画面の
// リビール演出(600ms)を待つには十分な時間を指定した `pump(duration)` を使う。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  testWidgets('ホーム→入力→結果の基本フローを一通り操作できる', (tester) async {
    await tester.pumpWidget(const NetaMakerApp());
    await _settle(tester);

    // ホーム画面に3カテゴリが並んでいる。
    for (final category in MakerCategory.values) {
      expect(find.text(category.title), findsOneWidget);
    }

    // 二つ名メーカーへ進む。
    await tester.tap(find.text(MakerCategory.futatsuna.title));
    await _settle(tester);

    // 空欄のまま送信するとエラーになる。
    await tester.tap(find.textContaining('診断する'));
    await _settle(tester);
    expect(find.text('名前を入力してね'), findsOneWidget);

    // 名前を入れて診断する。
    await tester.enterText(find.byType(TextFormField), 'たろう');
    await tester.tap(find.textContaining('診断する'));
    await _settle(tester);

    expect(find.text('『たろう』の二つ名は──'), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);
    expect(find.text('シェア'), findsOneWidget);

    String answerText() =>
        tester.widget<Text>(find.byKey(const Key('resultAnswer'))).data!;
    String detailText() =>
        tester.widget<Text>(find.byKey(const Key('resultDetail'))).data!;

    final firstAnswer = answerText();
    final firstDetail = detailText();

    // もう一度で結果が変わる(rerollNonceが変わるため)。
    await tester.tap(find.text('もう一度'));
    await _settle(tester);
    final changed = answerText() != firstAnswer || detailText() != firstDetail;
    expect(changed, isTrue);

    // ホームに戻れる。
    await tester.tap(find.text('ホームに戻る'));
    await _settle(tester);
    expect(find.text('ネタメーカー'), findsOneWidget);
  });

  testWidgets('同じ名前で再度診断すると最初と同じ結果になる(決定性)', (tester) async {
    await tester.pumpWidget(const NetaMakerApp());
    await _settle(tester);

    Future<String> diagnose(String name) async {
      await tester.tap(find.text(MakerCategory.zensei.title));
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField), name);
      await tester.tap(find.textContaining('診断する'));
      await _settle(tester);
      final answer = tester
          .widget<Text>(find.byKey(const Key('resultAnswer')))
          .data!;
      await tester.tap(find.text('ホームに戻る'));
      await _settle(tester);
      return answer;
    }

    final first = await diagnose('花子');
    final second = await diagnose('花子');
    expect(second, first);
  });
}
