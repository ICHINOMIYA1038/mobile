import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/catalog/seal_lines.dart';
import 'package:theater_log/widgets/pon_stamp.dart';

void main() {
  final names = [
    for (final v in (jsonDecode(File('../../packages/gikyoku_catalog/assets/catalog.json').readAsStringSync()) as Map)['venues'] as List) (v as Map)['name'] as String,
  ];

  test('全部の劇場名で、文字を落とさず 4 行以内に収まる', () {
    expect(names, isNotEmpty);
    for (final name in names) {
      final lines = sealLines(name);
      expect(lines.length, lessThanOrEqualTo(4), reason: name);
      String squash(String s) => s.replaceAll(RegExp(r'[ 　]'), '');
      expect(squash(lines.join()), squash(sealName(name)), reason: name);
    }
  });

  test('行の頭に、長音や小さい文字や送りがなが来ない', () {
    final bad = RegExp(r'^[ーぁぃぅぇぉっゃゅょァィゥェォッャュョ・）)、。のれ]');
    for (final name in names) {
      for (final line in sealLines(name).skip(1)) {
        expect(bad.hasMatch(line), isFalse, reason: '$name → ${sealLines(name)}');
      }
    }
  });

  test('言葉の切れ目で折り返す', () {
    expect(sealLines('東京芸術劇場').join('|'), '東京芸術劇場');
    expect(sealLines('動作確認の小さな劇場').join().contains('小さ\n'), isFalse);
    expect(sealLines('上田市交流文化芸術センター サントミューゼ').last, 'サントミューゼ');
    expect(sealLines('富山県民小劇場ORBIS').any((l) => l.contains('小劇場')), isTrue);
    expect(sealLines('高知市文化プラザかるぽーと').any((l) => l.contains('かるぽーと')), isTrue);
    expect(sealName('オーバードホール（富山市芸術文化ホール）'), 'オーバードホール');
  });

  testWidgets('いちばん長い名前でも、ハンコからあふれない', (tester) async {
    final longest = names.reduce((a, b) => sealName(a).length >= sealName(b).length ? a : b);
    await tester.pumpWidget(MaterialApp(home: Center(child: PonSeal(size: 200, label: sealLines(longest).join('\n'), sub: '東京都', fontSize: 21))));
    expect(tester.takeException(), isNull);
  });
}
