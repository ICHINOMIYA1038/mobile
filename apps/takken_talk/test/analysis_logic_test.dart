import 'package:flutter_test/flutter_test.dart';
import 'package:takken_talk/screens/pro/analysis_logic.dart';
import 'package:takken_talk/screens/pro/mock_result_screen.dart';

/// 苦手分析の見せ方（棒の印の位置・予測点の一言・癖の読み方）と、模擬試験の結果の絞り込み
void main() {
  group('0〜50点の棒の位置', () {
    test('合格点の目安と目標', () {
      expect(scorePos(36), closeTo(0.72, 1e-9));
      expect(scorePos(39), closeTo(0.78, 1e-9));
      expect(scorePos(0), 0);
      expect(scorePos(50), 1);
    });
    test('はみ出さない', () {
      expect(scorePos(-3), 0);
      expect(scorePos(60), 1);
      expect(scorePos(10, max: 0), 0);
    });
    test('科目の棒（問題数が上限）', () => expect(scorePos(18, max: 20), closeTo(0.9, 1e-9)));
  });

  group('予測点の一言', () {
    test('合格点に届かない', () => expect(forecastStatus(score: 30, passLine: 36, target: 39), '合格点の目安まであと6点'));
    test('合格圏', () => expect(forecastStatus(score: 37, passLine: 36, target: 39), '合格圏です。目標 39点まであと2点'));
    test('目標圏', () => expect(forecastStatus(score: 39, passLine: 36, target: 39), contains('目標圏')));
  });

  group('まちがい方の癖の読み方', () {
    Map<String, dynamic> habits({num? tf, int tfAsked = 20, num? dt, int dtAsked = 20, num? num_, num? other, int numAnswered = 20, int forgotten = 0, num? recent, num? before, int recentCount = 20, int beforeCount = 20}) => {
      'trustsFalse': {'rate': tf, 'asked': tfAsked, 'wrong': 0},
      'doubtsTrue': {'rate': dt, 'asked': dtAsked, 'wrong': 0},
      'numbers': {'accuracy': num_, 'othersAccuracy': other, 'answered': numAnswered},
      'forgotten': forgotten,
      'trend': {'recent': recent, 'before': before, 'recentCount': recentCount, 'beforeCount': beforeCount},
    };

    test('データが無ければ何も言わない', () {
      expect(habitNotes(null), isEmpty);
      expect(habitNotes(habits()), isEmpty);
    });

    test('誤りの文を正しいと思いがち（差 0.15 から）', () {
      expect(habitNotes(habits(tf: 0.40, dt: 0.25)).single, contains('誤りの文を正しいと思いがち'));
      expect(habitNotes(habits(tf: 0.39, dt: 0.25)), isEmpty, reason: '差 0.14');
    });

    test('正しい文まで疑いがち', () => expect(habitNotes(habits(tf: 0.1, dt: 0.3)).single, contains('正しい文まで誤りと思いがち')));

    test('答えた数が少ないうちは言わない', () {
      expect(habitNotes(habits(tf: 0.6, dt: 0.1, tfAsked: 9)), isEmpty);
      expect(habitNotes(habits(num_: 0.4, other: 0.9, numAnswered: 9)), isEmpty);
      expect(habitNotes(habits(recent: 0.9, before: 0.5, beforeCount: 5)), isEmpty);
    });

    test('数字の問題で点を落としている（差 0.15 から）', () {
      expect(habitNotes(habits(num_: 0.6, other: 0.75)).single, contains('数字の問題で点を落としています'));
      expect(habitNotes(habits(num_: 0.61, other: 0.75)), isEmpty);
      expect(habitNotes(habits(num_: 0.9, other: 0.6)), isEmpty, reason: '数字のほうができているなら言わない');
    });

    test('忘れは5問から', () {
      expect(habitNotes(habits(forgotten: 4)), isEmpty);
      expect(habitNotes(habits(forgotten: 5)).single, contains('5問忘れています'));
    });

    test('正答率の変化', () {
      expect(habitNotes(habits(recent: 0.8, before: 0.6)).single, contains('上がっています'));
      expect(habitNotes(habits(recent: 0.5, before: 0.7)).single, contains('下がっています'));
    });
  });

  test('割合と点の書き方', () {
    expect(pct(0.425), '43%');
    expect(pct(null), '—');
    expect(pts(15.24), '15.2');
    expect(pts(18), '18');
    expect(pts(18.0), '18');
  });

  group('模擬試験の結果の絞り込み', () {
    final items = [
      {'answer': true, 'correct': true},
      {'answer': false, 'correct': false},
      {'answer': null, 'correct': false},
    ];
    test('すべて・まちがえた（未回答も含む）・未回答', () {
      expect(mockFilter(items, 'all').map((e) => e.$1), [0, 1, 2]);
      expect(mockFilter(items, 'wrong').map((e) => e.$1), [1, 2]);
      expect(mockFilter(items, 'blank').map((e) => e.$1), [2]);
    });
  });
}
