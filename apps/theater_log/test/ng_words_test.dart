import 'package:flutter_test/flutter_test.dart';
import 'package:theater_log/account/ng_words.dart';

void main() {
  test('罵倒・リンクは公開させず、作品の筋としての言葉は公開できる', () {
    expect(ngReason('こいつ 死 ね'), 'ng_word');
    expect(ngReason('キチガイ'), 'ng_word');
    expect(ngReason('ｷﾁｶﾞｲ'), isNull, reason: '濁点の半角は別の文字になる。サーバーの NFKC で弾く');
    expect(ngReason('詳しくは https://example.test へ'), 'link');
    expect(ngReason('ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ'), 'link');
    expect(ngReason('主人公が恋人を殺す場面の照明が忘れられない。差別を扱う重い作品だった'), isNull);
    expect(ngReason('シネマ歌舞伎がよかった'), isNull);
    expect(ngReason(''), isNull);
  });
}
