import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// ○×の一覧表（サイトの fig/Matrix.svelte）。行が多く列が少ない表を、スマホでも表のまま見せる。
/// - 行はグループごとに色の帯。記号: ○ / ● = あてはまる（赤い丸）、× = あてはまらない、△ = 条件つき
/// - 列の幅はサイトの表（table-layout: auto）と同じ考え方で、中身の長さから決める
/// - 入りきらないときだけ横にスクロールし、行の見出しは左に留める
class MatrixBody extends StatefulWidget {
  const MatrixBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  State<MatrixBody> createState() => _MatrixBodyState();
}

enum _Kind { yes, no, cond, text }

typedef _Cell = ({_Kind kind, String rest});

final _markRe = RegExp(r'^([○●◯×✕△▲])\s*(.*)$', dotAll: true);

_Cell _parse(String c) {
  final m = _markRe.firstMatch(c.trim());
  if (m == null) return (kind: _Kind.text, rest: c);
  final mark = m.group(1)!;
  final kind = (mark == '×' || mark == '✕') ? _Kind.no : (mark == '△' || mark == '▲') ? _Kind.cond : _Kind.yes;
  return (kind: kind, rest: m.group(2)!);
}

const _bands = [(Color(0xFF8CC5A3), Color(0xFFF1F8F3)), (Color(0xFFE7B07A), Color(0xFFFCF3EA)), (Color(0xFF8FB0D9), Color(0xFFEEF3FA)), (Color(0xFFB9B3DD), Color(0xFFF3F1FA))];
const _dotColor = Color(0xFFD0453F);
const _xColor = Color(0xFF3D6AB0);

class _MatrixBodyState extends State<MatrixBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.raw;
    final columns = maps(raw['columns']).map((c) => (label: str(c['label']), note: optStr(c['note']))).toList();
    final n = columns.length;
    final groups = maps(raw['groups'])
        .map((g) => (
              label: optStr(g['label']),
              rows: maps(g['rows']).map((r) {
                final cells = strs(r['cells']);
                return (label: str(r['label']), cells: [for (var i = 0; i < n; i++) _parse(i < cells.length ? cells[i] : '')]);
              }).toList(),
            ))
        .toList();
    final legend = maps(raw['legend']).map((l) => (mark: str(l['mark']), meaning: str(l['meaning']))).toList();
    final footnotes = strs(raw['footnotes']);

    final many = n >= 6;
    // 行の名前が長い表は、名前を折り返して値の列に幅を残す
    final longRows = groups.any((g) => g.rows.any((r) => r.label.length > 10));
    final s = _Styles(many: many, base: DefaultTextStyle.of(context).style);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxWidth;
      final m = _Measure(s, scaler);

      // ---- 行の見出しの列 ----
      final labelMax = groups.expand((g) => g.rows).fold<double>(0, (w, r) => math.max(w, m.max(TextSpan(text: r.label, style: s.rowHead))));
      double labelContent;
      if (many) {
        labelContent = labelMax.clamp(6.2 * 12, 7.0 * 12);
      } else if (longRows) {
        labelContent = labelMax.clamp(6.5 * 13, 9.0 * 13);
      } else {
        labelContent = labelMax;
      }
      var labelW = labelContent + 16 + 1;

      // ---- 値の列: 一番短くできる幅（min）と、折り返さない幅（max） ----
      final padX = many ? 4.0 : 12.0;
      final minCell = (many ? 2.1 : 2.6) * 14 * scaler.scale(1);
      final mins = List<double>.filled(n, 0);
      final maxs = List<double>.filled(n, 0);
      for (var j = 0; j < n; j++) {
        final head = m.max(TextSpan(text: columns[j].label, style: s.head));
        var lo = math.max(minCell, head);
        var hi = lo;
        if (columns[j].note != null) {
          final note = TextSpan(text: columns[j].note, style: s.cnote);
          lo = math.max(lo, m.min(note));
          hi = math.max(hi, m.max(note));
        }
        for (final g in groups) {
          for (final r in g.rows) {
            final c = r.cells[j];
            lo = math.max(lo, m.cellMin(c));
            hi = math.max(hi, m.cellMax(c));
          }
        }
        mins[j] = lo + padX;
        maxs[j] = hi + padX;
      }
      final sumMin = mins.fold<double>(0, (a, b) => a + b);
      final sumMax = maxs.fold<double>(0, (a, b) => a + b);
      // 値の列が入りきらないときは、横にスクロールさせる前に行の名前を折り返して幅を譲る（5字までは残す）
      if (!many && sumMin > avail - labelW) {
        labelContent = math.min(labelContent, math.max(5 * 13 * scaler.scale(1), avail - 17 - sumMin));
        labelW = labelContent + 16 + 1;
      }
      final room = avail - labelW;
      final List<double> widths;
      if (sumMax <= room) {
        // 余りは値の列に、中身の長さの比で配る（表は幅いっぱい）
        widths = [for (final w in maxs) w + (room - sumMax) * w / sumMax];
      } else if (sumMin <= room) {
        final t = (room - sumMin) / (sumMax - sumMin);
        widths = [for (var j = 0; j < n; j++) mins[j] + (maxs[j] - mins[j]) * t];
      } else {
        widths = mins;
      }
      final scrolls = sumMin > room + 0.5;
      final total = labelW + widths.fold<double>(0, (a, b) => a + b);

      Widget sticky(Widget child) => scrolls
          ? AnimatedBuilder(animation: _scroll, builder: (context, child) => Transform.translate(offset: Offset(_scroll.hasClients ? _scroll.offset : 0, 0), child: child), child: child)
          : child;

      final table = <Widget>[
        // 見出しの行
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: labelW, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.inkSoft, width: 2)))),
              for (var j = 0; j < n; j++)
                Container(
                  width: widths[j],
                  padding: EdgeInsets.fromLTRB(padX / 2, many ? 0 : 7, padX / 2, 8),
                  alignment: Alignment.bottomCenter,
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.inkSoft, width: 2))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(columns[j].label, style: s.head, softWrap: false, textAlign: TextAlign.center),
                      if (columns[j].note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(columns[j].note!, style: s.cnote, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (var gi = 0; gi < groups.length; gi++) ...[
          if (groups[gi].label != null)
            SizedBox(
              width: total,
              child: sticky(Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: math.min(total, avail) - 12),
                  child: Text(groups[gi].label!, style: s.ghead),
                ),
              )),
            ),
          for (final r in groups[gi].rows) _row(r, _bands[gi % _bands.length], labelW, widths, s, padX, sticky),
        ],
      ];

      final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: table);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scrolls) const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('表は横にスクロールできます →', style: TextStyle(fontSize: fsSub, height: 1.5, color: Palette.inkSoft))),
          if (scrolls) SingleChildScrollView(controller: _scroll, scrollDirection: Axis.horizontal, child: SizedBox(width: total, child: body)) else body,
          if (legend.isNotEmpty || footnotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (legend.isNotEmpty)
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final l in legend)
                    Text.rich(
                      TextSpan(children: [_legendMark(l.mark), TextSpan(text: ' ${l.meaning}')]),
                      style: const TextStyle(fontSize: fsSub, height: 1.6, color: Palette.inkSoft),
                    ),
                ],
              ),
            for (final f in footnotes) Padding(padding: const EdgeInsets.only(top: 2), child: Text(f, style: const TextStyle(fontSize: fsSub, height: 1.6, color: Palette.inkSoft))),
          ],
        ],
      );
    });
  }

  Widget _row(({String label, List<_Cell> cells}) r, (Color, Color) band, double labelW, List<double> widths, _Styles s, double padX, Widget Function(Widget) sticky) {
    const bottom = Border(bottom: BorderSide(color: Palette.line));
    final label = Container(
      width: labelW,
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 7), // 左の帯 4 と合わせてサイトの padding-left 10
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Color.lerp(Palette.paper, band.$2, 0.6),
        border: Border(left: BorderSide(color: band.$1, width: 4), bottom: const BorderSide(color: Palette.line)),
      ),
      child: Text(r.label, style: s.rowHead),
    );
    return Stack(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 高さを決めるための見えない見出し（見える方は上に重ねて、横のスクロールで左に留める）
              Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: label),
              for (var j = 0; j < widths.length; j++)
                Container(
                  width: widths[j],
                  padding: EdgeInsets.symmetric(horizontal: padX / 2, vertical: s.many ? 6 : 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: band.$2, border: bottom),
                  child: Text.rich(_cellSpan(r.cells[j], s), textAlign: TextAlign.center, style: s.cell),
                ),
            ],
          ),
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: sticky(label)),
      ],
    );
  }

  static InlineSpan _dot(double size) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(width: size, height: size, decoration: const BoxDecoration(color: _dotColor, shape: BoxShape.circle)),
      );

  static InlineSpan _cellSpan(_Cell c, _Styles s) {
    final rest = c.rest.isEmpty ? null : TextSpan(text: c.kind == _Kind.text ? c.rest : ' ${c.rest}', style: c.kind == _Kind.text ? s.text : s.rest);
    return TextSpan(children: [
      switch (c.kind) {
        _Kind.yes => _dot(13),
        _Kind.no => const TextSpan(text: '×', style: _Styles.x),
        _Kind.cond => const TextSpan(text: '△', style: _Styles.tri),
        _Kind.text => const TextSpan(),
      },
      ?rest,
    ]);
  }

  static InlineSpan _legendMark(String mark) => switch (_parse(mark).kind) {
        _Kind.yes => _dot(10),
        _Kind.no => const TextSpan(text: '×', style: _Styles.x),
        _Kind.cond => const TextSpan(text: '△', style: _Styles.tri),
        _Kind.text => TextSpan(text: mark),
      };
}

class _Styles {
  _Styles({required this.many, required TextStyle base})
      : head = base.merge(TextStyle(fontSize: many ? 12 : 13, height: 1.35, fontWeight: FontWeight.w700, color: Palette.ink)),
        cnote = base.merge(const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, color: Palette.inkSoft)),
        rowHead = base.merge(TextStyle(fontSize: many ? 12 : 13, height: 1.4, fontWeight: FontWeight.w700, color: Palette.ink)),
        ghead = base.merge(const TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
        cell = base.merge(const TextStyle(fontSize: 14, height: 1.45, color: Palette.ink)),
        rest = base.merge(const TextStyle(fontSize: 12, height: 1.45, color: Palette.inkSoft)),
        text = base.merge(const TextStyle(fontSize: 13, height: 1.45, color: Palette.ink));
  final bool many;
  final TextStyle head, cnote, rowHead, ghead, cell, rest, text;
  static const x = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _xColor);
  static const tri = TextStyle(fontWeight: FontWeight.w700, color: Palette.warning);
}

/// 文字の幅を測る（TextPainter）。記号の丸は文字ではないので幅を足す
class _Measure {
  _Measure(this.s, this.scaler);
  final _Styles s;
  final TextScaler scaler;

  TextPainter _lay(InlineSpan span) => TextPainter(text: span, textDirection: TextDirection.ltr, textScaler: scaler)..layout();

  double max(InlineSpan span) {
    final p = _lay(span);
    final w = p.maxIntrinsicWidth;
    p.dispose();
    return w.ceilToDouble() + 1;
  }

  // 日本語は1字ごとに折り返せるが、TextPainter の minIntrinsicWidth は和文の折り返し位置を見ず、文全体の幅を返す。
  // そこで、折り返せない塊（英数字の続き＋行頭に来られない記号）ごとに測って一番広いものにする
  static final _chunk = RegExp(r'[0-9A-Za-z０-９.,，．%％/\-]+[〜～、。，）)」』%％]*|.[〜～、。，）)」』]*', dotAll: true);

  double min(TextSpan span) {
    final text = span.text ?? '';
    var w = 0.0;
    for (final m in _chunk.allMatches(text)) {
      w = math.max(w, max(TextSpan(text: m.group(0), style: span.style)));
    }
    return w;
  }

  ({double head, TextSpan? rest}) _parts(_Cell c) {
    final TextSpan? rest = c.rest.isEmpty ? null : TextSpan(text: c.rest, style: c.kind == _Kind.text ? s.text : s.rest);
    final head = switch (c.kind) {
      _Kind.yes => 13.0,
      _Kind.no => max(TextSpan(text: '×', style: s.cell.merge(_Styles.x))),
      _Kind.cond => max(TextSpan(text: '△', style: s.cell.merge(_Styles.tri))),
      _Kind.text => 0.0,
    };
    return (head: head, rest: rest);
  }

  double cellMax(_Cell c) {
    final p = _parts(c);
    return p.head + (p.rest == null ? 0 : max(p.rest!) + 2);
  }

  double cellMin(_Cell c) {
    final p = _parts(c);
    return math.max(p.head, p.rest == null ? 0 : min(p.rest!));
  }
}
