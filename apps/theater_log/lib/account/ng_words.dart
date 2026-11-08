/// 公開させない言葉とリンク。サーバー（gikyoku_tosyokan の lib/app-ng-words.ts）と同じ決まりで、
/// 保存したその場で「非公開で保存した」と伝えるために使う。最終的な判定はサーバーが行う
library;

const _base = [
  '死ね', '氏ね', 'しねよ', '死んでしまえ', '殺すぞ', 'ころすぞ', 'ぶっ殺', 'ぶっころ', 'くたばれ',
  'きちがい', '基地外', '気違い', '池沼', '知恵遅れ', 'がいじが', 'がいじは', 'がいじw',
  'ちんぽ', 'まんこ', 'ちんこしゃぶ', 'ふぇらちお',
];

String _hiragana(String s) => String.fromCharCodes(s.runes.map((c) => c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c));

/// 全角英数を半角に、半角カナを全角にそろえる（NFKC の代わり。必要な分だけ）
String _width(String s) {
  const half = 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
  const full = 'ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0xFF01 && c <= 0xFF5E) {
      b.writeCharCode(c - 0xFEE0);
    } else {
      final i = half.indexOf(String.fromCharCode(c));
      b.write(i >= 0 ? full[i] : String.fromCharCode(c));
    }
  }
  return b.toString();
}

String _normalize(String s) => _hiragana(_width(s).toLowerCase()).replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

/// 公開させない言葉か宣伝のリンクがあれば、その理由を返す
String? ngReason(String text) {
  if (text.isEmpty) return null;
  if (RegExp(r'https?://|www\.|line\.me/', caseSensitive: false).hasMatch(_width(text))) return 'link';
  final key = _normalize(text);
  return _base.map(_normalize).any(key.contains) ? 'ng_word' : null;
}
