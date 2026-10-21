import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 比べる。2列までは表（左に項目、右に値）。3列以上は行ごとに値を並べる（狭いときは縦に積んで列名を添える）。
class CompareBody extends StatelessWidget {
  const CompareBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  static bool _same(List<String> cells) => cells.length > 1 && cells.every((c) => c.trim() == cells[0].trim());

  // 2列の表で同じ値の行を1つにまとめるのは、値が長くて2列にまたがって見えるときだけ。
  // 「受けられる」のような短い値をまとめると左の列だけに書いたように見えるので、両方の列に書く（サイトの merge）
  static bool _merge(List<String> cells) => _same(cells) && cells[0].trim().length > 10;

  @override
  Widget build(BuildContext context) {
    final columns = strs(raw['columns']);
    final rows = maps(raw['rows']).map((r) => (label: str(r['label']), cells: _pad(strs(r['cells']), columns.length))).toList();
    if (columns.length <= 2) return _table(columns, rows);
    // サイトは図（枠を含む）の幅 520px 以下で縦に積む。本体の左右の余白 14×2 を引いた幅で見る
    return LayoutBuilder(builder: (context, c) => c.maxWidth > 492 ? _grid(columns, rows) : _stacked(columns, rows));
  }

  static List<String> _pad(List<String> cells, int n) => [for (var i = 0; i < n; i++) i < cells.length ? cells[i] : ''];

  Widget _table(List<String> columns, List<({String label, List<String> cells})> rows) {
    const pad = EdgeInsets.symmetric(vertical: 9, horizontal: 10);
    const line = BorderSide(color: Palette.line);
    Widget head(int i) => Container(
          padding: pad,
          decoration: BoxDecoration(
            color: Palette.columns[i % 2],
            borderRadius: BorderRadius.only(
              topLeft: i == 0 ? const Radius.circular(6) : Radius.zero,
              topRight: i == columns.length - 1 ? const Radius.circular(6) : Radius.zero,
            ),
          ),
          child: Text(columns[i], style: const TextStyle(fontSize: fsLabel, height: 1.6, fontWeight: FontWeight.w700, color: Colors.white)),
        );
    Widget cell(List<InlineSpan> spans) => Padding(padding: pad, child: Text.rich(TextSpan(children: spans), style: bodyStyle));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 30),
              for (var i = 0; i < columns.length; i++) Expanded(flex: 70 ~/ columns.length, child: head(i)),
            ],
          ),
        ),
        for (var ri = 0; ri < rows.length; ri++)
          DecoratedBox(
            decoration: BoxDecoration(border: ri == rows.length - 1 ? null : const Border(bottom: line)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 30,
                    child: Container(
                      color: Palette.fill,
                      padding: pad,
                      child: Text(rows[ri].label, style: const TextStyle(fontSize: fsLabel, height: 1.6, fontWeight: FontWeight.w700, color: Palette.ink)),
                    ),
                  ),
                  if (_merge(rows[ri].cells))
                    Expanded(flex: 70, child: cell([allChip('どちらも'), ...valueSpans(rows[ri].cells[0])]))
                  else
                    for (final v in rows[ri].cells) Expanded(flex: 70 ~/ columns.length, child: cell(valueSpans(v))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 狭いとき: 行ごとに「項目名」→ 列名の札つきで値を縦に
  Widget _stacked(List<String> columns, List<({String label, List<String> cells})> rows) => Ruled(
        children: [
          for (var ri = 0; ri < rows.length; ri++)
            Padding(
              padding: EdgeInsets.only(top: ri == 0 ? 0 : 10, bottom: ri == rows.length - 1 ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(rows[ri].label),
                  if (_same(rows[ri].cells))
                    Text.rich(TextSpan(children: [allChip('すべて'), ...valueSpans(rows[ri].cells[0])]), style: bodyStyle)
                  else
                    for (var i = 0; i < rows[ri].cells.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${columns[i]}  ', style: TextStyle(fontSize: fsSub, fontWeight: FontWeight.w700, color: Palette.columns[i % 4])),
                            ...valueSpans(rows[ri].cells[i]),
                          ]),
                          style: bodyStyle,
                        ),
                      ),
                ],
              ),
            ),
        ],
      );

  /// 広いとき: 見出しの行（色で列を覚える）→ 行ごとに値を横に並べる
  Widget _grid(List<String> columns, List<({String label, List<String> cells})> rows) {
    Widget across(List<Widget> cells) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: cells[i])],
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        across([
          for (var i = 0; i < columns.length; i++)
            Container(
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Palette.columns[i % 4], width: 3))),
              child: Text(columns[i], style: TextStyle(fontSize: fsLabel, height: 1.5, fontWeight: FontWeight.w700, color: Palette.columns[i % 4])),
            ),
        ]),
        Ruled(
          children: [
            for (var ri = 0; ri < rows.length; ri++)
              Padding(
                padding: EdgeInsets.only(top: 10, bottom: ri == rows.length - 1 ? 0 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(rows[ri].label),
                    if (_same(rows[ri].cells))
                      Text.rich(TextSpan(children: [allChip('すべて'), ...valueSpans(rows[ri].cells[0])]), style: bodyStyle)
                    else
                      across([for (final v in rows[ri].cells) Text.rich(TextSpan(children: valueSpans(v)), style: bodyStyle)]),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s, style: const TextStyle(fontSize: fsSub, height: 1.6, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
      );
}
