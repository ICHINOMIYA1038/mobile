import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fp1_talk/models/core.dart';
import 'package:fp1_talk/widgets/figure/kinds.dart';

/// サイトの教材（pairof-shikaku の content/fp1/figures/*.json）の図を全部アプリで描いて、
/// はみ出し（RenderFlex overflowed など）や例外が出ないことを見る。
/// 教材はサイトのリポジトリにあるので、手元にないときは飛ばす。
const _figuresDir = '/Users/ichinomiya/private/pairof-shikaku/content/fp1/figures';

List<FigureData> _loadFigures() {
  final dir = Directory(_figuresDir);
  if (!dir.existsSync()) return const [];
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      for (final j in (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['figures'] as List) FigureData.fromJson((j as Map).cast<String, dynamic>()),
  ];
}

void main() {
  final figures = _loadFigures();

  test('教材の図が読める', () {
    if (figures.isEmpty) {
      markTestSkipped('教材が見つからない: $_figuresDir');
      return;
    }
    expect(figures.length, greaterThan(0));
  });

  test('illust だけが WebView に回る', () {
    for (final f in figures) {
      expect(nativeFigureBody(f) == null, f.kind == 'illust', reason: '${f.id} (${f.kind})');
    }
  });

  // スマホ（幅 390）の図の本体はおよそ 330。狭い機種（SE など）や分割表示も見て 290 も
  for (final bodyWidth in const [330.0, 290.0]) {
    for (final f in figures.where((f) => f.kind != 'illust')) {
      testWidgets('${f.id} (${f.kind}) 幅 $bodyWidth', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 2000 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(child: SizedBox(width: bodyWidth, child: nativeFigureBody(f))),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
