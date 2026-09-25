import '../models.dart';

/// 図解を検索するための、中身をぜんぶ平らにした文字列を作る。
/// 「2週間」「保証金」のような語で、どのカードにその数字が入っているかを横断で探せる。
String figureHaystack(Figure f) {
  final parts = <String>[f.title, f.hint, f.note ?? '', f.topicKey];
  switch (f.kind) {
    case 'compare':
      parts.addAll(f.columns);
      for (final r in f.rows) {
        parts.add(r.label);
        parts.addAll(r.cells);
      }
    case 'buckets':
      for (final g in f.groups) {
        parts.add(g.title);
        parts.addAll(g.items);
      }
    case 'numbers':
      for (final i in f.items) {
        parts.addAll([i.value, i.label, i.note ?? '']);
      }
    case 'flow':
      for (final s in f.steps) {
        parts.addAll([s.title, s.detail ?? '']);
      }
    case 'nest':
      void walk(List<FigureNode> ns) {
        for (final n in ns) {
          parts.addAll([n.title, n.note ?? '']);
          walk(n.children);
        }
      }
      walk(f.nodes);
  }
  return parts.join(' ').toLowerCase();
}

/// 図解の型。表示名と、どんなときに使う型かの一言。
class FigureKind {
  const FigureKind(this.key, this.label, this.blurb);
  final String key;
  final String label;
  final String blurb;

  static const all = [
    FigureKind('compare', '比較表', '並べて違いを見る'),
    FigureKind('buckets', 'グループ分け', 'どちらに入るかで覚える'),
    FigureKind('numbers', '数字', '期間・金額・割合'),
    FigureKind('flow', '流れ図', '順番が問われるもの'),
    FigureKind('nest', '入れ子', '区域や階層の構造'),
  ];

  static String labelOf(String kind) {
    for (final k in all) {
      if (k.key == kind) return k.label;
    }
    return kind;
  }
}
