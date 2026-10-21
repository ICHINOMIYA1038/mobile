import 'package:flutter/material.dart';

import '../theme.dart';

/// 本試験の問題文・設例の塊（サイトの src/lib/examText.ts と同じ分け方）。
/// 表は Markdown の表（| a | b |）、ほかは段落（改行はそのまま）。
sealed class ExamBlock {
  const ExamBlock();
}

class ExamParagraph extends ExamBlock {
  const ExamParagraph(this.text);
  final String text;
}

class ExamTable extends ExamBlock {
  const ExamTable(this.head, this.rows);
  final List<String>? head;
  final List<List<String>> rows;
}

List<String> _cells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return t.split('|').map((c) => c.trim()).toList();
}

final _rule = RegExp(r'^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$');
bool _isRule(String line) => _rule.hasMatch(line.trim());

List<ExamBlock> examBlocks(String text) {
  final out = <ExamBlock>[];
  final lines = text.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  var para = <String>[];
  void flush() {
    final t = para.join('\n').trim();
    if (t.isNotEmpty) out.add(ExamParagraph(t));
    para = [];
  }

  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trim().startsWith('|')) {
      if (lines[i].trim().isEmpty) {
        flush();
      } else {
        para.add(lines[i]);
      }
      continue;
    }
    flush();
    final tbl = <String>[];
    while (i < lines.length && lines[i].trim().startsWith('|')) {
      tbl.add(lines[i++]);
    }
    i--;
    // 2行目が区切り線（|---|）なら1行目は見出し
    final hasHead = tbl.length > 1 && _isRule(tbl[1]);
    final body = [
      for (final (k, l) in tbl.indexed)
        if (!(hasHead && k == 1) && !_isRule(l)) l,
    ];
    out.add(ExamTable(hasHead ? _cells(body.first) : null, (hasHead ? body.skip(1) : body).map(_cells).toList()));
  }
  flush();
  return out;
}

/// 問題文・設例を段落と表で出す。表は横にスクロールして読む（列が多い財務データなど）
class ExamText extends StatelessWidget {
  const ExamText(this.text, {super.key, this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 14.0 : 15.0;
    final style = TextStyle(fontSize: size, height: 1.75, color: Palette.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in examBlocks(text))
          switch (b) {
            ExamParagraph(:final text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(text, style: style),
              ),
            ExamTable() => Padding(padding: const EdgeInsets.only(bottom: 12), child: _Table(b)),
          },
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table(this.t);
  final ExamTable t;

  @override
  Widget build(BuildContext context) {
    final cols = [t.head?.length ?? 0, ...t.rows.map((r) => r.length)].fold(0, (a, b) => a > b ? a : b);
    List<String> pad(List<String> r) => [...r, for (var i = r.length; i < cols; i++) ''];
    Widget cell(String s, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            s,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Palette.ink, fontWeight: head ? FontWeight.w700 : FontWeight.w400, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        );
    return Semantics(
      label: '表（横にスクロールできます）',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: Palette.lineStrong),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            if (t.head != null) TableRow(decoration: const BoxDecoration(color: Palette.fill), children: [for (final c in pad(t.head!)) cell(c, head: true)]),
            for (final r in t.rows) TableRow(children: [for (final c in pad(r)) cell(c)]),
          ],
        ),
      ),
    );
  }
}
