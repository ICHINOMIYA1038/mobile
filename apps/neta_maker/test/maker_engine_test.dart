import 'package:flutter_test/flutter_test.dart';
import 'package:neta_maker/logic/maker_engine.dart';
import 'package:neta_maker/logic/seeded_random.dart';
import 'package:neta_maker/models/maker_result.dart';

void main() {
  group('決定的生成', () {
    for (final category in MakerCategory.values) {
      test('${category.name}: 同じ入力なら常に同じ結果になる', () {
        final first = generateMakerResult(category: category, input: 'たろう');
        final second = generateMakerResult(category: category, input: 'たろう');
        expect(second.headline, first.headline);
        expect(second.answer, first.answer);
        expect(second.detail, first.detail);
        expect(second.shareText, first.shareText);
      });

      test('${category.name}: rerollNonceを変えると結果が変わりうる', () {
        // 同じ名前でも、40通り試せば少なくとも1回はrerollで結果が変わるはず。
        final base = generateMakerResult(category: category, input: 'はなこ');
        final rerolled = List.generate(
          40,
          (i) => generateMakerResult(
            category: category,
            input: 'はなこ',
            rerollNonce: i + 1,
          ),
        );
        expect(
          rerolled.any(
            (r) => r.answer != base.answer || r.detail != base.detail,
          ),
          isTrue,
        );
      });

      test('${category.name}: 前後の空白を除いて同じ入力とみなす', () {
        final a = generateMakerResult(category: category, input: 'じろう');
        final b = generateMakerResult(category: category, input: '  じろう  ');
        expect(b.answer, a.answer);
        expect(b.detail, a.detail);
      });

      test('${category.name}: 結果に空文字/欠損がない', () {
        for (final name in ['さくら', 'ゆうた', 'A', 'テスト太郎']) {
          final result = generateMakerResult(category: category, input: name);
          expect(result.headline, isNotEmpty);
          expect(result.answer, isNotEmpty);
          expect(result.detail, isNotEmpty);
          expect(result.shareText, isNotEmpty);
          expect(result.shareText.contains(name), isTrue);
        }
      });
    }

    test('脳内メーカーはキーワードを4件、重複なく返す', () {
      for (final name in ['さくら', 'ゆうた', 'テスト太郎', '名前']) {
        final result = generateMakerResult(
          category: MakerCategory.nounai,
          input: name,
        );
        expect(result.keywords, hasLength(4));
        expect(result.keywords.map((k) => k.label).toSet(), hasLength(4));
        for (final k in result.keywords) {
          expect(k.label, isNotEmpty);
          expect(k.instinctRatio, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('二つ名・前世メーカーはキーワードを使わない(空リスト)', () {
      for (final category in [MakerCategory.futatsuna, MakerCategory.zensei]) {
        final result = generateMakerResult(category: category, input: 'てすと');
        expect(result.keywords, isEmpty);
      }
    });
  });

  group('seeded_random', () {
    test('stableHashは同じ入力なら常に同じ値を返す', () {
      expect(stableHash('abc'), stableHash('abc'));
      expect(stableHash('abc'), isNot(stableHash('abd')));
    });

    test('pickDistinctは重複なくcount件を返す', () {
      final random = seededRandomFor(category: 'x', input: 'y');
      final picked = pickDistinct(random, List.generate(30, (i) => i), 10);
      expect(picked, hasLength(10));
      expect(picked.toSet(), hasLength(10));
    });
  });

  group('コンテンツの網羅性', () {
    test('全カテゴリで最低20種類以上の結果パターンが出せる(単調な使い回しを防ぐ)', () {
      // 脳内メーカーの answer(理性型/バランス型/本能型)は意図的に3択の粗い分類
      // なので、answer単体ではなく keywords・detail も含めた結果全体の
      // バリエーションを見る。
      for (final category in MakerCategory.values) {
        final signatures = <String>{};
        for (var i = 0; i < 60; i++) {
          final r = generateMakerResult(
            category: category,
            input: 'サンプル$i',
          );
          final keywordSignature = r.keywords.map((k) => k.label).join(',');
          signatures.add('${r.answer}|${r.detail}|$keywordSignature');
        }
        expect(
          signatures.length,
          greaterThanOrEqualTo(20),
          reason: '${category.name}の結果パターンが少なすぎる(単調な診断に見える恐れ)',
        );
      }
    });
  });
}
