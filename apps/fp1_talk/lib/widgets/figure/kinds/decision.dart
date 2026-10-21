import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 判断の分かれ道（サイトの fig/DecisionSteps.svelte）。start から質問をたどって、上から答えていく列にする。
/// - 先へ進む答えは下向きの矢印（「はい」↓）、答えが出る枝は横向きの矢印（「いいえ」→）で結論の箱へ
/// - 最後の質問は、片方を横へ、もう片方を下の結論へ
/// - 両方の答えが次の質問に続くときは「はいの場合」「いいえの場合」に分ける（狭ければ縦に積む）
/// 幅が 360 未満（スマホはほぼこちら）は右の列をやめ、質問の左寄りから下へ幹を通して結論を枝分かれさせる
class DecisionBody extends StatelessWidget {
  const DecisionBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final nodes = <String, _Node>{};
    if (raw['nodes'] is Map) {
      (raw['nodes'] as Map).forEach((k, v) {
        if (v is Map) nodes['$k'] = _Node(q: optStr(v['q']), yes: optStr(v['yes']), no: optStr(v['no']), result: optStr(v['result']), tone: optStr(v['tone']));
      });
    }
    return LayoutBuilder(builder: (context, c) => _Chain(nodes: nodes, start: str(raw['start']), from: 1, narrow: c.maxWidth < 360, splitWide: c.maxWidth >= 520));
  }
}

class _Node {
  const _Node({this.q, this.yes, this.no, this.result, this.tone});
  final String? q, yes, no, result, tone;
}

typedef _Exit = ({String answer, _Node node});
typedef _Ans = ({String answer, String id});

/// 質問1つ。kind が split なら branches に分かれる
class _Step {
  _Step({required this.no, required this.q, this.side, this.down, this.end, this.branches});
  final int no;
  final String q;
  final _Exit? side;
  final _Ans? down;
  final _Exit? end;
  final List<_Ans>? branches;
}

const _arrow = Palette.inkFaint;
const _spine = 18.0;

class _Chain extends StatelessWidget {
  const _Chain({required this.nodes, required this.start, required this.from, required this.narrow, this.splitWide = false});
  final Map<String, _Node> nodes;
  final String start;
  final int from;

  /// 右の列をやめて縦に積む（狭いとき・分かれ道の中）
  final bool narrow;

  /// 分かれ道を左右に並べる（広いとき）
  final bool splitWide;

  bool _isQ(String? id) => id != null && nodes[id]?.q != null;
  bool _isR(String? id) => id != null && nodes[id]?.result != null;

  /// start から一本道をたどって、質問の列にする
  List<_Step> _walk() {
    final out = <_Step>[];
    String? cur = start;
    var no = from;
    for (var guard = 0; cur != null && guard < 12; guard++) {
      final n = nodes[cur];
      if (n?.q == null) break;
      final answers = <_Ans>[if (n!.yes != null) (answer: 'はい', id: n.yes!), if (n.no != null) (answer: 'いいえ', id: n.no!)];
      final exits = [for (final a in answers) if (_isR(a.id)) (answer: a.answer, node: nodes[a.id]!)];
      final conts = [for (final a in answers) if (_isQ(a.id)) a];
      if (conts.length >= 2) {
        out.add(_Step(no: no, q: n.q!, side: exits.firstOrNull, branches: conts));
        break;
      }
      // 続きがなければ、結論の1つ目を横へ、2つ目を下へ（下が流れの終わり）
      out.add(_Step(no: no, q: n.q!, side: exits.firstOrNull, down: conts.firstOrNull, end: conts.isEmpty && exits.length > 1 ? exits[1] : null));
      cur = conts.firstOrNull?.id;
      no++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in _walk()) _step(s)]);
  }

  Widget _step(_Step s) {
    final forks = s.branches != null;
    final rowNarrow = narrow || forks;
    final children = <Widget>[];
    if (rowNarrow) {
      children.add(_question(s));
      if (s.side != null) children.add(_SideNarrow(s.side!));
    } else {
      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 115, child: _question(s)),
          Expanded(flex: 100, child: s.side == null ? const SizedBox() : _SideWide(s.side!)),
        ],
      ));
    }
    // 下の矢印と結論は、広いときは質問の箱の幅（1.15 / 2.15）に合わせて、その真ん中に
    Widget underQ(Widget w) => narrow ? w : FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 1.15 / 2.15, child: w);
    if (!forks) {
      if (s.down != null) {
        children.add(underQ(_Down(answer: s.down!.answer, atSpine: narrow)));
      } else if (s.end != null) {
        children.add(underQ(_Down(answer: s.end!.answer, atSpine: narrow)));
        children.add(underQ(_result(s.end!.node)));
      }
    } else {
      final sections = [
        for (final b in s.branches!)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${b.answer}の場合', textAlign: splitWide ? TextAlign.center : TextAlign.start, style: const TextStyle(fontSize: fsLabel, height: 1.6, fontWeight: FontWeight.w700, color: Palette.primary)),
              _Down(answer: null, atSpine: !splitWide),
              _Chain(nodes: nodes, start: b.id, from: s.no + 1, narrow: true),
            ],
          ),
      ];
      children.add(CustomPaint(
        painter: _SplitLines(wide: splitWide),
        child: Padding(
          padding: EdgeInsets.only(top: splitWide ? 26 : 14),
          child: splitWide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: sections[i])]])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 14), sections[i]]]),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _question(_Step s) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.primary, width: 2), borderRadius: BorderRadius.circular(10)),
        child: Text.rich(
          TextSpan(children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 6),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Palette.primary, shape: BoxShape.circle),
                child: Text('${s.no}', style: const TextStyle(fontSize: fsSub, height: 1, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            ...numSpans(s.q),
          ]),
          style: const TextStyle(fontSize: fsBody, height: 1.55, fontWeight: FontWeight.w700, color: Palette.ink),
        ),
      );
}

Widget _result(_Node n) {
  final (bg, edge) = switch (n.tone) {
    'yes' => (Palette.successSoft, Palette.success),
    'no' => (Palette.dangerSoft, Palette.danger),
    'warn' => (Palette.warningSoft, Palette.warning),
    _ => (Palette.fill, Palette.lineStrong),
  };
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
    decoration: BoxDecoration(color: bg, border: Border.all(color: edge, width: 1.5), borderRadius: BorderRadius.circular(10)),
    child: Text.rich(TextSpan(children: numSpans(n.result ?? '')), style: const TextStyle(fontSize: fsLabel, height: 1.55, fontWeight: FontWeight.w700, color: Palette.ink)),
  );
}

const _lblStyle = TextStyle(fontSize: fsSub, height: 1.3, fontWeight: FontWeight.w700, color: Palette.inkSoft, backgroundColor: Palette.paper);

/// 答えが出る枝（狭いとき）: 幹から右へ矢印を出し、その先に結論
class _SideNarrow extends StatelessWidget {
  const _SideNarrow(this.exit);
  final _Exit exit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: _spine - 1),
        child: CustomPaint(
          painter: const _Trunk(),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 34, height: 40, child: _Right(exit.answer)),
                Expanded(child: _result(exit.node)),
              ],
            ),
          ),
        ),
      );
}

/// 答えが出る枝（広いとき）: 質問の箱の右へ矢印、その先に結論
class _SideWide extends StatelessWidget {
  const _SideWide(this.exit);
  final _Exit exit;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [SizedBox(width: 40, height: 40, child: _Right(exit.answer)), Expanded(child: _result(exit.node))],
      );
}

/// 横の矢印（→）。答えは線の上に
class _Right extends StatelessWidget {
  const _Right(this.answer);
  final String answer;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _RightArrow(),
        child: Align(
          alignment: const Alignment(0, -1),
          child: Padding(padding: const EdgeInsets.only(right: 6), child: Text(answer, softWrap: false, overflow: TextOverflow.visible, style: _lblStyle)),
        ),
      );
}

class _RightArrow extends CustomPainter {
  const _RightArrow();
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p = Paint()..color = _arrow;
    canvas.drawRect(Rect.fromLTRB(0, y - 1, size.width - 6, y + 1), p);
    canvas.drawPath(Path()
      ..moveTo(size.width - 7, y - 6)
      ..lineTo(size.width, y)
      ..lineTo(size.width - 7, y + 6)
      ..close(), p);
  }

  @override
  bool shouldRepaint(_RightArrow oldDelegate) => false;
}

/// 狭いときの幹: 横の枝の左端を上から下まで通る線
class _Trunk extends CustomPainter {
  const _Trunk();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Rect.fromLTRB(0, 0, 2, size.height), Paint()..color = _arrow);

  @override
  bool shouldRepaint(_Trunk oldDelegate) => false;
}

/// 下の矢印（↓）。狭いときは幹の位置、広いときは質問の箱の真ん中。答えは線の右に
class _Down extends StatelessWidget {
  const _Down({required this.answer, required this.atSpine});
  final String? answer;
  final bool atSpine;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: LayoutBuilder(builder: (context, c) {
          final x = atSpine ? _spine : c.maxWidth / 2;
          return CustomPaint(
            size: Size(c.maxWidth, 34),
            painter: _DownArrow(x),
            child: answer == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(left: x + 8, bottom: 8),
                    child: Align(alignment: Alignment.centerLeft, child: Text(answer!, softWrap: false, style: _lblStyle)),
                  ),
          );
        }),
      );
}

class _DownArrow extends CustomPainter {
  const _DownArrow(this.x);
  final double x;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _arrow;
    canvas.drawRect(Rect.fromLTRB(x - 1, 0, x + 1, size.height - 7), p);
    canvas.drawPath(Path()
      ..moveTo(x - 6, size.height - 7)
      ..lineTo(x + 6, size.height - 7)
      ..lineTo(x, size.height)
      ..close(), p);
  }

  @override
  bool shouldRepaint(_DownArrow old) => old.x != x;
}

/// 分かれ道の線。縦に積むときは幹を短く下ろし、左右に並べるときは真ん中から左右の列の真ん中へ
class _SplitLines extends CustomPainter {
  const _SplitLines({required this.wide});
  final bool wide;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _arrow;
    if (!wide) {
      canvas.drawRect(const Rect.fromLTRB(_spine - 1, 0, _spine + 1, 12), p);
      return;
    }
    final w = size.width;
    canvas.drawRect(Rect.fromLTRB(w / 2 - 1, 0, w / 2 + 1, 12), p);
    canvas.drawRect(Rect.fromLTRB(w * 0.25 - 4, 12, w * 0.75 + 4, 14), p);
    // 各列の「はいの場合」の上まで下ろす
    for (final x in [w * 0.25 - 4, w * 0.75 + 4]) {
      canvas.drawRect(Rect.fromLTRB(x - 1, 12, x + 1, 26), p);
    }
  }

  @override
  bool shouldRepaint(_SplitLines old) => old.wide != wide;
}
