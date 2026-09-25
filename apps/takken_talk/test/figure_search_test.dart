import 'package:flutter_test/flutter_test.dart';
import 'package:takken_talk/models.dart';
import 'package:takken_talk/widgets/figure_search.dart';

Figure _fig({
  required String kind,
  List<String> columns = const [],
  List<FigureRow> rows = const [],
  List<FigureGroup> groups = const [],
  List<FigureItem> items = const [],
  List<FigureStep> steps = const [],
  List<FigureNode> nodes = const [],
  String? note,
}) =>
    Figure(
      id: 'f1',
      chapterId: 'ch01',
      topicKey: 'hosho',
      title: '営業保証金と保証協会',
      kind: kind,
      hint: '2つの制度を並べて確認するとき',
      note: note,
      columns: columns,
      rows: rows,
      groups: groups,
      items: items,
      steps: steps,
      nodes: nodes,
    );

void main() {
  group('図解の検索', () {
    test('比較表の見出しとセルまで拾う', () {
      final h = figureHaystack(_fig(
        kind: 'compare',
        columns: ['営業保証金', '保証協会'],
        rows: [const FigureRow(label: '主たる事務所', cells: ['1,000万円', '60万円'])],
      ));
      expect(h.contains('1,000万円'), isTrue);
      expect(h.contains('主たる事務所'), isTrue);
      expect(h.contains('保証協会'), isTrue);
    });

    test('数字カードの値・見出し・注記を拾う', () {
      final h = figureHaystack(_fig(kind: 'numbers', items: [
        const FigureItem(value: '2週間', label: '不足額の供託', note: '通知を受けた日から'),
      ]));
      expect(h.contains('2週間'), isTrue);
      expect(h.contains('通知を受けた日から'), isTrue);
    });

    test('入れ子は子まで再帰的に拾う', () {
      final h = figureHaystack(_fig(kind: 'nest', nodes: [
        const FigureNode(title: '建物', note: null, children: [
          FigureNode(title: '共用部分', note: null, children: [
            FigureNode(title: '規約共用部分', note: '登記しないと対抗できない', children: []),
          ]),
        ]),
      ]));
      expect(h.contains('規約共用部分'), isTrue);
      expect(h.contains('登記しないと対抗できない'), isTrue);
    });

    test('グループ分け・流れ図・注記も拾い、小文字で返す', () {
      final b = figureHaystack(_fig(
        kind: 'buckets',
        groups: [const FigureGroup(title: '取引にあたる', tone: 'yes', items: ['自ら 売買'])],
        note: '自ら貸借だけが取引に入らない',
      ));
      expect(b.contains('自ら 売買'), isTrue);
      expect(b.contains('自ら貸借だけが取引に入らない'), isTrue);

      final f = figureHaystack(_fig(kind: 'flow', steps: [
        const FigureStep(title: '免許を受ける', detail: 'この時点ではまだ営業できない'),
      ]));
      expect(f.contains('まだ営業できない'), isTrue);
      expect(f, equals(f.toLowerCase()));
    });
  });

  group('図解の型', () {
    test('5種類そろっていて、表示名が引ける', () {
      expect(FigureKind.all.length, 5);
      expect(FigureKind.labelOf('compare'), '比較表');
      expect(FigureKind.labelOf('nest'), '入れ子');
      expect(FigureKind.labelOf('unknown'), 'unknown');
    });
  });
}
