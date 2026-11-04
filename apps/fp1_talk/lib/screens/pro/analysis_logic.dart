// 苦手分析の画面で使う、画面から切り離した計算（test/analysis_logic_test.dart で確かめる）。
// 数字そのものはサイトが出す（src/lib/server/analysis.ts の Report）。ここでは見せ方だけを決める。

/// 0〜50点の棒の上の位置（0.0〜1.0）。予測点・合格点の目安・目標の印に使う
double scorePos(num score, {num max = 50}) => max <= 0 ? 0 : (score / max).clamp(0.0, 1.0).toDouble();

/// 予測点の見出しの下の一言
String forecastStatus({required int score, required int passLine, required int target}) {
  if (score >= target) return '目標圏です（目標 $target点）';
  if (score >= passLine) return '合格圏です。目標 $target点まであと${target - score}点';
  return '合格点の目安まであと${passLine - score}点';
}

/// 「癖」を言い切るのに要る数（少ないうちは、たまたまの差と区別できない）
const habitMinSample = 10;

/// 差がこれ以上なら目立つとみなす
const habitGap = 0.15;

num? _rate(Object? m) => m is Map ? m['rate'] as num? : null;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// まちがい方の癖から読み取れること（目立つものだけ。無ければ空）
/// items: 本試験形式（FP1）の記録から作った癖（trustsFalse は「不適切なものを選ぶ問」、numbers は数値・計算の欄）
List<String> habitNotes(Map<String, dynamic>? h, {bool items = false}) {
  if (h == null) return const [];
  final notes = <String>[];
  final tf = (h['trustsFalse'] as Map?)?.cast<String, dynamic>();
  final dt = (h['doubtsTrue'] as Map?)?.cast<String, dynamic>();
  final tfRate = _rate(tf);
  final dtRate = _rate(dt);
  if (tfRate != null && dtRate != null && _int(tf?['asked']) >= habitMinSample && _int(dt?['asked']) >= habitMinSample) {
    if (tfRate - dtRate >= habitGap) {
      notes.add(items ? '「不適切なもの」を選ぶ問で点を落としています。問いの向きに印を付け、選択肢ごとに○×を書いてから選びましょう' : '誤りの文を正しいと思いがちです。文末の結論を疑って読みましょう');
    }
    if (dtRate - tfRate >= habitGap) {
      notes.add(items ? '「適切なもの」を選ぶ問で点を落としています。正しそうな選択肢の数字・条件を、知っている決まりと照らしましょう' : '正しい文まで誤りと思いがちです。ひっかけを探しすぎず、知っている決まりと照らしましょう');
    }
  }
  final n = (h['numbers'] as Map?)?.cast<String, dynamic>();
  final numAcc = n?['accuracy'] as num?;
  final otherAcc = n?['othersAccuracy'] as num?;
  if (numAcc != null && otherAcc != null && _int(n?['answered']) >= habitMinSample && otherAcc - numAcc >= habitGap) {
    notes.add(items ? '数値・計算の欄で点を落としています。応用編の計算は、模範の計算過程の順に電卓で解き直しましょう' : '数字の問題で点を落としています。期間・金額などの数字は図解でまとめて覚えましょう');
  }
  final forgotten = _int(h['forgotten']);
  if (forgotten >= 5) notes.add('一度できた問題を$forgotten問忘れています。「復習」で間隔をあけて解き直しましょう');
  final t = (h['trend'] as Map?)?.cast<String, dynamic>();
  final recent = t?['recent'] as num?;
  final before = t?['before'] as num?;
  if (recent != null && before != null && _int(t?['recentCount']) >= habitMinSample && _int(t?['beforeCount']) >= habitMinSample) {
    if (recent - before >= habitGap) notes.add('直近の正答率が上がっています。この調子で進めましょう');
    if (before - recent >= habitGap) notes.add('直近の正答率が下がっています。新しい章に進む前に、まちがえた問題を見直しましょう');
  }
  return notes;
}

/// 割合を「42%」に（無ければ —）
String pct(Object? v) => v is num ? '${(v * 100).round()}%' : '—';

/// 予測点の小数（15.2）。整数なら 18
String pts(Object? v) {
  if (v is! num) return '—';
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);
}
