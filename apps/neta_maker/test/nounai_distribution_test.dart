import 'package:flutter_test/flutter_test.dart';
import 'package:neta_maker/logic/maker_engine.dart';
import 'package:neta_maker/models/maker_result.dart';

void main() {
  test('脳内メーカーの3分類は、どれか1つに偏りすぎない', () {
    final counts = <String, int>{};
    for (var i = 0; i < 3000; i++) {
      final r = generateMakerResult(
        category: MakerCategory.nounai,
        input: 'name$i',
        rerollNonce: 0,
      );
      counts[r.answer] = (counts[r.answer] ?? 0) + 1;
    }
    expect(counts.keys.toSet(), {'理性型', 'バランス型', '本能型'});
    for (final entry in counts.entries) {
      expect(entry.value, greaterThan(3000 * 0.2), reason: '${entry.key} が少なすぎる');
      expect(entry.value, lessThan(3000 * 0.5), reason: '${entry.key} が多すぎる');
    }
  });
}
