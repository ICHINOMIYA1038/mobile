// 劇場名をハンコの中で読みやすい位置で折り返す

const _maxLines = 4;
const _targetWidth = 7.0;

/// 漢字の並びの中で、言葉の切れ目になりやすい語
const _words = ['小劇場', '大劇場', '中劇場', '小ホール', '大ホール', '劇場', '会館', '文化', '芸術', '市民', '県民', '区民', '府民', '都民', '総合', '交流', '県立', '府立', '都立', '市立', '区立', '町立', '公会堂', '工房', '美術館', '博物館'];

enum _Kind { kanji, hiragana, katakana, latin, other }

_Kind _kindOf(int c) {
  if (c >= 0x3041 && c <= 0x309F) return _Kind.hiragana;
  if ((c >= 0x30A1 && c <= 0x30FF) || c == 0xFF0D) return _Kind.katakana;
  if ((c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005) return _Kind.kanji;
  if (c < 0x3000) return _Kind.latin;
  return _Kind.other;
}

/// 括弧の中の正式名や別名は、ハンコには入れない
String sealName(String name) {
  final i = name.indexOf(RegExp(r'[（(]'));
  final main = i > 0 ? name.substring(0, i) : name;
  return main.trim();
}

List<String> _tokens(String name) {
  final tokens = <String>[];
  for (final part in name.split(RegExp(r'[ 　]+'))) {
    if (part.isEmpty) continue;
    var current = StringBuffer();
    _Kind? prev;
    var wordEnd = 0;
    final runes = part.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final c = runes[i];
      // 長音と中黒は前の文字の続き（かるぽーと、神戸新開地・など）
      final kind = (c == 0x30FC || c == 0x30FB) && prev != null ? prev : _kindOf(c);
      var atWord = false;
      if (kind == _Kind.kanji && i >= wordEnd) {
        for (final w in _words) {
          if (part.startsWith(w, i)) {
            atWord = prev == _Kind.kanji;
            wordEnd = i + w.length;
            break;
          }
        }
      }
      // 送りがなや助詞は前の語につける
      final breaks = prev != null && (atWord || (kind != prev && kind != _Kind.hiragana && !(prev == _Kind.latin && kind == _Kind.kanji && runes[i - 1] >= 0x30 && runes[i - 1] <= 0x39)));
      if (breaks && current.isNotEmpty) {
        tokens.add(current.toString());
        current = StringBuffer();
      }
      current.writeCharCode(c);
      prev = kind;
      // 漢字の後の中黒は、そこで折り返せる
      if (c == 0x30FB && kind != _Kind.katakana && i + 1 < runes.length) {
        tokens.add(current.toString());
        current = StringBuffer();
        continue;
      }
      // 市立などの語は、次の語と切り離せるようにする
      if (i + 1 == wordEnd && i + 1 < runes.length && _kindOf(runes[i + 1]) == _Kind.kanji) {
        tokens.add(current.toString());
        current = StringBuffer();
      }
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    tokens.add(' '); // 空白の切れ目の印
  }
  if (tokens.isNotEmpty) tokens.removeLast();
  return tokens;
}

double _widthOf(String s) => s.runes.fold(0.0, (a, c) => a + (c < 0x3000 ? 0.58 : 1.0));

/// 行数をなるべく少なく、行の長さをなるべくそろえて分ける
List<String> sealLines(String name) {
  final tokens = _tokens(sealName(name));
  final pieces = <(String, bool)>[]; // 語と、前に空白があったか
  var spaced = false;
  for (final t in tokens) {
    if (t == ' ') {
      spaced = true;
    } else {
      pieces.add((t, spaced));
      spaced = false;
    }
  }
  if (pieces.isEmpty) return [name];
  String join(int from, int to) {
    final b = StringBuffer();
    for (var i = from; i < to; i++) {
      if (i > from && pieces[i].$2) b.write(' ');
      b.write(pieces[i].$1);
    }
    return b.toString();
  }

  List<String>? best;
  for (var k = 1; k <= _maxLines && k <= pieces.length; k++) {
    final split = _bestSplit(pieces.length, k, (a, b) => _widthOf(join(a, b)));
    final lines = [for (var i = 0; i + 1 < split.length; i++) join(split[i], split[i + 1])];
    final widest = lines.map(_widthOf).reduce((a, b) => a > b ? a : b);
    best = best == null || widest < best.map(_widthOf).reduce((a, b) => a > b ? a : b) ? lines : best;
    if (widest <= _targetWidth) break;
  }
  return best!;
}

/// いちばん長い行が最も短くなる区切りを返す
List<int> _bestSplit(int n, int k, double Function(int, int) width) {
  final memo = <(int, int), (double, List<int>)>{};
  (double, List<int>) go(int from, int left) {
    if (left == 1) return (width(from, n), [from, n]);
    return memo.putIfAbsent((from, left), () {
      (double, List<int>)? best;
      for (var to = from + 1; to <= n - left + 1; to++) {
        final rest = go(to, left - 1);
        final w = width(from, to);
        final worst = w > rest.$1 ? w : rest.$1;
        if (best == null || worst < best.$1) best = (worst, [from, ...rest.$2]);
      }
      return best!;
    });
  }

  return go(0, k).$2;
}
