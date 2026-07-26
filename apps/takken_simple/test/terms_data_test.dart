import 'package:flutter_test/flutter_test.dart';
import 'package:takken_simple/data/terms_data.dart';

void main() {
  test('主要用語を50語以上収録している', () {
    expect(baseTerms.length, greaterThanOrEqualTo(50));
  });

  test('用語ID・名称・別名が重複していない', () {
    expect(baseTerms.map((term) => term.id).toSet().length, baseTerms.length);

    final labels = <String>[];
    for (final term in baseTerms) {
      labels.add(term.name);
      labels.addAll(term.aliases);
    }
    expect(labels.toSet().length, labels.length);
  });

  test('主要4科目の用語を収録している', () {
    for (final category in ['宅建業法', '権利関係', '法令上の制限', '税その他']) {
      expect(
        baseTerms.where((term) => term.category == category),
        isNotEmpty,
        reason: '$category の用語がありません',
      );
    }
  });

  test('表記ゆれからも関連用語を抽出できる', () {
    expect(extractRelatedTerms('専属専任媒介契約とレインズ'), hasLength(2));
    expect(extractRelatedTerms('建ぺい率の上限'), hasLength(1));
  });

  test('用語集に廃止済みの大臣免許申請経由を残さない', () {
    final text = baseTerms.map((term) => term.detailedDescription).join('\n');
    expect(text, isNot(contains('都道府県知事を経由して行います')));
    expect(text, isNot(contains('完成野物件')));
  });
}
