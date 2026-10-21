import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp1_talk/widgets/exam_text.dart';

/// 問題文・設例の分け方（サイトの src/lib/examText.ts と同じ）
void main() {
  test('段落と Markdown の表に分ける。2行目が区切り線なら1行目は見出し', () {
    final b = examBlocks('〈財務データ〉 （単位：百万円）\n| | 2026年３月期 |\n|---|---|\n| 売上高 | 189,000 |\n| 営業利益 | 13,500 |\n\n※上記以外の条件は考慮しない。');
    expect(b.length, 3);
    expect((b[0] as ExamParagraph).text, '〈財務データ〉 （単位：百万円）');
    final t = b[1] as ExamTable;
    expect(t.head, ['', '2026年３月期']);
    expect(t.rows, [
      ['売上高', '189,000'],
      ['営業利益', '13,500'],
    ]);
    expect((b[2] as ExamParagraph).text, '※上記以外の条件は考慮しない。');
  });

  test('区切り線の無い表は全部が本体。段落の中の改行は残す', () {
    final b = examBlocks('1行目\n2行目\n| a | b |\n| c | d |');
    expect((b[0] as ExamParagraph).text, '1行目\n2行目');
    expect((b[1] as ExamTable).head, isNull);
    expect((b[1] as ExamTable).rows.length, 2);
  });

  testWidgets('列の多い表は横にスクロールして読める（はみ出さない）', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final wide = '| ${List.generate(8, (i) => '列$i の見出しの長い文字').join(' | ')} |\n|${List.filled(8, '---').join('|')}|\n| ${List.generate(8, (i) => '${i}00,000').join(' | ')} |';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ExamText(wide)))));
    expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
    expect(find.ancestor(of: find.byType(Table), matching: find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal)), findsOneWidget);
  });
}
