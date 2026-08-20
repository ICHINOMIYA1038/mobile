import 'dart:math';

/// 文字列から安定したハッシュ値を作る(FNV-1a 32bit)。
///
/// `String.hashCode` はDartのバージョン/実行環境間で値が一致する保証がないため、
/// 「同じ入力なら常に同じ診断結果になる」という要件には使えない。
/// このハッシュはアルゴリズムを変えない限り常に同じ値を返す。
int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash = (hash ^ unit) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// 診断カテゴリ・入力文字列・再抽選回数(rerollNonce)から決定的な[Random]を作る。
///
/// 同じ [category] + [input](前後空白を除いて正規化) + [rerollNonce] であれば、
/// 何度呼び出しても同じ乱数列を返す。「もう一度」ボタンは [rerollNonce] を
/// 明示的にインクリメントした呼び出しでのみ別結果を出す。これにより、
/// 「同じ回答なのに毎回違う診断結果が返ってくる」という不満(既存アプリのレビューで
/// 頻出していた問題)を構造的に避ける。
Random seededRandomFor({
  required String category,
  required String input,
  int rerollNonce = 0,
}) {
  final normalized = input.trim();
  return Random(stableHash('$category::$normalized::$rerollNonce'));
}

/// [random] を使って [list] から重複なく [count] 件を選ぶ。
/// [count] が [list] の長さ以上の場合は [list] 全体をシャッフルして返す。
List<T> pickDistinct<T>(Random random, List<T> list, int count) {
  final pool = List<T>.of(list);
  final result = <T>[];
  final take = count.clamp(0, pool.length);
  for (var i = 0; i < take; i++) {
    final index = random.nextInt(pool.length - i);
    result.add(pool[index]);
    pool[index] = pool[pool.length - i - 1];
  }
  return result;
}

/// [openers] と [closers] から前半・後半をそれぞれ独立に選んで1文を作る。
String pickSentence(Random random, List<String> openers, List<String> closers) {
  final opener = openers[random.nextInt(openers.length)];
  final closer = closers[random.nextInt(closers.length)];
  return '$opener$closer';
}

/// [pickSentence] で2文を独立に選び、連結して返す。
///
/// 同じ語彙バンクから2回抽選しているだけなので新しい文章を書き足す必要が
/// なく、それでいて実質的な組み合わせ数は(前半数×後半数)の2乗に増える。
/// 偶然2文とも全く同じになった場合(「Aだった。Aだった。」のような不自然な
/// 繰り返し)は、2文目だけ選び直す(最大5回)。
String pickTwoSentences(
  Random random,
  List<String> openers,
  List<String> closers,
) {
  final first = pickSentence(random, openers, closers);
  var second = pickSentence(random, openers, closers);
  for (var i = 0; i < 5 && second == first; i++) {
    second = pickSentence(random, openers, closers);
  }
  return '$first$second';
}
