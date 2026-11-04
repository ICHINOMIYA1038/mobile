import 'package:flutter_test/flutter_test.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:gikyoku_library/catalog/filter.dart';
import 'package:gikyoku_library/screens/shortlist_screen.dart';

Play _play({int id = 1, String title = '作品', int? man, int? woman, int? others, int? total, int? minutes, String? readUrl, List<int> cats = const []}) => Play.fromJson({
  'id': id, 'title': title, 'author': '作者', 'man': man, 'woman': woman, 'others': others, 'total': total, 'minutes': minutes,
  'synopsis': null, 'aiDescription': null, 'readUrl': readUrl, 'buyUrl': null, 'categoryIds': cats, 'awards': [], 'groups': [],
});

void main() {
  group('PlayFilter', () {
    test('人数と時間の範囲。不明な作品は絞り込むと出ない', () {
      final plays = [_play(id: 1, total: 2, minutes: 30), _play(id: 2, total: 5, minutes: 60), _play(id: 3)];
      expect(PlayFilter(cast: castRanges[1]).apply(plays).map((p) => p.id), [1]);
      expect(PlayFilter(minutes: minuteRanges[1]).apply(plays).map((p) => p.id).toSet(), {1, 2});
      expect(const PlayFilter().apply(plays).length, 3);
    });
    test('キーワードは空白と大文字小文字を無視する', () {
      final plays = [_play(id: 1, title: 'THE BEE'), _play(id: 2, title: '赤鬼')];
      expect(const PlayFilter(keyword: 'the  bee').apply(plays).single.id, 1);
    });
    test('ジャンルと読み先', () {
      final plays = [_play(id: 1, cats: [5], readUrl: 'https://a'), _play(id: 2, cats: [6])];
      expect(const PlayFilter(categoryIds: {6}).apply(plays).single.id, 2);
      expect(const PlayFilter(readableOnly: true).apply(plays).single.id, 1);
    });
    test('情報がそろった作品を先に出す', () {
      final plays = [_play(id: 1), _play(id: 2, total: 2, minutes: 30)];
      expect(const PlayFilter().apply(plays).first.id, 2);
    });
  });

  test('共有の文面に作品名と URL が入る', () {
    final text = shortlistShareText([_play(id: 206, title: 'フランダースの負け犬', total: 2, minutes: 60)]);
    expect(text, contains('フランダースの負け犬'));
    expect(text, contains('https://gikyokutosyokan.com/posts/206'));
  });

}
