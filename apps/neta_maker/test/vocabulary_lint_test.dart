import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 語彙バンクの品質を機械的に固定する。
/// - 悪口になりうる語を入れない(方針: 悪口寄りの単語を一切採用しない)
/// - 前半が '' でも文として成立しない後半(「というタイプ。」等)を入れない
/// - 同じ語を重複して入れない(確率の偏り)
void main() {
  final files = [
    'lib/data/generators/nounai_bank.dart',
    'lib/data/generators/zensei_bank.dart',
    'lib/data/generators/futatsuna_bank.dart',
  ];
  final quoted = RegExp(r"'([^'\\]*)'");

  test('悪口・不成立な後半・酒類の語彙が入っていない', () {
    const banned = [
      '気持ちが悪い',
      '一番苦手なタイプ',
      'というタイプ。',
      'それが愛されるポイントのタイプ。',
      'それが信条というタイプ。',
      'それを糧にしていた。',
      'お酒欲',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final word in banned) {
        expect(source.contains("'$word'"), isFalse, reason: '$path: $word');
      }
    }
  });

  test('各バンク内で同じ語彙が重複していない', () {
    for (final path in files) {
      final source = File(path).readAsStringSync();
      // const リストごとに検査する。
      final lists = RegExp(r'= \[(.*?)\];', dotAll: true).allMatches(source);
      for (final list in lists) {
        final items = quoted
            .allMatches(list.group(1)!)
            .map((m) => m.group(1)!)
            .where((s) => s.isNotEmpty)
            .toList();
        final dupes = <String>{};
        final seen = <String>{};
        for (final item in items) {
          if (!seen.add(item)) dupes.add(item);
        }
        expect(dupes, isEmpty, reason: '$path: $dupes');
      }
    }
  });
}
