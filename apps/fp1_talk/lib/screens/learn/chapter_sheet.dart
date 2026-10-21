import 'package:flutter/material.dart';

import '../../models/core.dart';
import '../../theme.dart';
import '../../widgets/figure/figure_view.dart';
import '../../widgets/rich_text.dart';
import 'learn_models.dart';

/// シートを閉じたあとに会話の画面がすること
sealed class SheetAction {}

/// 先生にその論点を説明してもらう（pointId で送る）
class TeachPoint extends SheetAction {
  TeachPoint(this.point);
  final OutlinePoint point;
}

/// その論点の○×を解く（文で頼む。サイトのテキストの「○×を解く」と同じ）
class QuizPoint extends SheetAction {
  QuizPoint(this.point);
  final OutlinePoint point;
}

/// ほかの章へ移る
class OpenChapter extends SheetAction {
  OpenChapter(this.chapterId);
  final String chapterId;
}

/// 目次とテキスト（サイトのスマホの「目次／テキスト」の引き出しと同じ中身）。
/// 開いているあいだは会話は進まないので、説明済みなどの印は開いたときのものでよい。
Future<SheetAction?> showChapterSheet(
  BuildContext context, {
  required LearnChapter chapter,
  required Set<String> taught,
  required Set<String> answered,
  required String? currentTopic,
  required String? currentPoint,
  required Map<String, FigureData> figures,
  required List<Term> glossary,
  required bool canTeach,
  required String pace,
  required ValueChanged<String> onPace,
  Neighbor? prev,
  Neighbor? next,
  String? textPointId,
}) =>
    showModalBottomSheet<SheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Palette.paper,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => _ChapterSheet(
          scroll: scroll,
          chapter: chapter,
          taught: taught,
          answered: answered,
          currentTopic: currentTopic,
          currentPoint: currentPoint,
          figures: figures,
          glossary: glossary,
          canTeach: canTeach,
          pace: pace,
          onPace: onPace,
          prev: prev,
          next: next,
          textPointId: textPointId,
        ),
      ),
    );

class _ChapterSheet extends StatefulWidget {
  const _ChapterSheet({
    required this.scroll,
    required this.chapter,
    required this.taught,
    required this.answered,
    required this.currentTopic,
    required this.currentPoint,
    required this.figures,
    required this.glossary,
    required this.canTeach,
    required this.pace,
    required this.onPace,
    required this.prev,
    required this.next,
    required this.textPointId,
  });
  final ScrollController scroll;
  final LearnChapter chapter;
  final Set<String> taught;
  final Set<String> answered;
  final String? currentTopic;
  final String? currentPoint;
  final Map<String, FigureData> figures;
  final List<Term> glossary;
  final bool canTeach;
  final String pace;
  final ValueChanged<String> onPace;
  final Neighbor? prev;
  final Neighbor? next;
  final String? textPointId;

  @override
  State<_ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<_ChapterSheet> {
  late bool _text = widget.textPointId != null;

  /// テキストで開いている論点。無ければいまの論点、それも無ければ最初の論点
  late String? _viewId = widget.textPointId ?? widget.currentPoint ?? widget.chapter.points.firstOrNull?.id;
  late String _pace = widget.pace;

  bool _done(OutlinePoint p) => widget.taught.contains(p.id) && p.questionIds.every(widget.answered.contains);

  void _openText(String id) {
    setState(() {
      _viewId = id;
      _text = true;
    });
    if (widget.scroll.hasClients) widget.scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: false, label: Text('目次')), ButtonSegment(value: true, label: Text('テキスト'))],
                  selected: {_text},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _text = s.first),
                ),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), style: TextButton.styleFrom(minimumSize: const Size(56, 44)), child: const Text('閉じる')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _text ? _textView(context) : _outline(context)),
      ],
    );
  }

  // ---------- 目次 ----------

  Widget _outline(BuildContext context) {
    final c = widget.chapter;
    final total = c.points.length;
    final done = c.points.where(_done).length;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (c.goal.isNotEmpty) Text(c.goal, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.inkSoft)),
        const SizedBox(height: 12),
        const Text('進め方', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        SegmentedButton<String>(
          segments: [for (final p in paces) ButtonSegment(value: p.key, label: Text(p.label, style: const TextStyle(fontSize: 13)))],
          selected: {_pace},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _pace = s.first);
            widget.onPace(s.first);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(paces.firstWhere((p) => p.key == _pace, orElse: () => paces[1]).note, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
        ),
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(child: Text('この章で学ぶこと', style: TextStyle(fontWeight: FontWeight.w700))),
            Text('終わった論点 $done/$total', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 6, backgroundColor: Palette.fillStrong, color: Palette.primary),
        ),
        for (final (i, t) in c.topics.indexed) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              '${i + 1}. ${t.title}',
              style: TextStyle(fontWeight: FontWeight.w700, color: t.key == widget.currentTopic ? Palette.primary : Palette.ink),
            ),
          ),
          for (final p in t.points) _pointRow(p),
        ],
        const SizedBox(height: 12),
        const Text(
          '論点を押すと、先生がその論点を説明します。先生に説明してもらうと「説明済み」になり、その論点の○×を全部答えると線が引かれます。',
          style: TextStyle(fontSize: 13, height: 1.6, color: Palette.inkFaint),
        ),
        if (widget.prev != null || widget.next != null) ...[
          const Divider(height: 32),
          if (widget.prev != null) _chapterLink('← 前の章', widget.prev!),
          if (widget.next != null) _chapterLink('次の章 →', widget.next!),
        ],
      ],
    );
  }

  Widget _pointRow(OutlinePoint p) {
    final d = _done(p);
    final taught = widget.taught.contains(p.id);
    final now = p.id == widget.currentPoint;
    return Material(
      color: now ? Palette.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: d ? '（終わった）' : taught ? '（説明済み・○×が残っている）' : '（まだ）',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.canTeach ? () => Navigator.of(context).pop(TeachPoint(p)) : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(d ? '✓' : taught ? '◐' : '', style: TextStyle(fontWeight: FontWeight.w700, color: d ? Palette.success : Palette.primary)),
                        ),
                        Expanded(
                          child: Text(
                            p.title,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: d ? Palette.inkSoft : Palette.ink,
                              fontWeight: now ? FontWeight.w700 : FontWeight.w400,
                              decoration: d ? TextDecoration.lineThrough : null,
                              decorationColor: Palette.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 説明を受けずに読むだけならテキストで
          IconButton(
            tooltip: 'テキストで読む',
            onPressed: () => _openText(p.id),
            icon: const Icon(Icons.menu_book_outlined, size: 20, color: Palette.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _chapterLink(String label, Neighbor n) => InkWell(
        onTap: () => Navigator.of(context).pop(OpenChapter(n.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label  ', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
              TextSpan(text: n.title, style: const TextStyle(color: Palette.primary, fontWeight: FontWeight.w700)),
            ])),
          ),
        ),
      );

  // ---------- テキスト ----------

  Widget _textView(BuildContext context) {
    final c = widget.chapter;
    final all = c.points;
    final idx = all.indexWhere((p) => p.id == _viewId);
    if (idx < 0) return const Center(child: Text('この章には論点がありません'));
    final p = all[idx];
    final ti = c.topics.indexWhere((t) => t.points.any((q) => q.id == p.id));
    final t = c.topics[ti];
    final pi = t.points.indexWhere((q) => q.id == p.id);
    final taught = widget.taught.contains(p.id);
    final answered = p.questionIds.where(widget.answered.contains).length;
    final figs = [for (final id in p.figureIds) ?widget.figures[id]];
    const body = TextStyle(fontSize: 16, height: 1.75, color: Palette.ink);
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'テーマ ', style: TextStyle(color: Palette.inkSoft)),
          TextSpan(text: '${ti + 1} ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: t.title),
        ]), style: const TextStyle(fontSize: 13, color: Palette.ink)),
        const SizedBox(height: 8),
        // 同じテーマの論点の番号。押すとその論点のテキストへ
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, q) in t.points.indexed)
              ChoiceChip(
                label: Text('${ti + 1}-${i + 1}${widget.taught.contains(q.id) ? ' ✓' : ''}'),
                selected: q.id == p.id,
                onSelected: (_) => _openText(q.id),
                selectedColor: Palette.primarySoft,
                tooltip: q.title,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('${ti + 1}-${pi + 1}  ${p.title}', style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          TextSpan(text: taught ? '説明済み' : 'まだ説明を受けていない', style: TextStyle(color: taught ? Palette.success : Palette.inkSoft, fontWeight: taught ? FontWeight.w700 : FontWeight.w400)),
          if (p.questionIds.isNotEmpty) TextSpan(text: '　○× $answered/${p.questionIds.length}'),
        ]), style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
        const SizedBox(height: 10),
        for (final s in _sentences(p.summary))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: s.example
                ? Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(6)),
                    child: Text.rich(TextSpan(children: [
                      const TextSpan(text: '例  ', style: TextStyle(fontWeight: FontWeight.w700, color: Palette.warning)),
                      ...RichBody.spans(context, s.text, widget.glossary, body),
                    ]), style: body),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('・', style: body),
                      Expanded(child: RichBody(s.text, glossary: widget.glossary, style: body)),
                    ],
                  ),
          ),
        for (final f in figs) Padding(padding: const EdgeInsets.only(top: 8), child: FigureView(figure: f, shownOn: 'learn')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.canTeach ? () => Navigator.of(context).pop(TeachPoint(p)) : null,
          child: Text(taught ? 'もう一度説明してもらう' : '先生に説明してもらう'),
        ),
        if (p.questionIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: widget.canTeach ? () => Navigator.of(context).pop(QuizPoint(p)) : null, child: const Text('○×を解く')),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (idx > 0)
              Expanded(child: _pager('← 前の論点', all[idx - 1], CrossAxisAlignment.start))
            else
              const Spacer(),
            const SizedBox(width: 8),
            if (idx < all.length - 1)
              Expanded(child: _pager('次の論点 →', all[idx + 1], CrossAxisAlignment.end))
            else
              const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _pager(String label, OutlinePoint p, CrossAxisAlignment align) => InkWell(
        onTap: () => _openText(p.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
              Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start, style: const TextStyle(fontSize: 14, color: Palette.primary)),
            ],
          ),
        ),
      );

  /// 要約を「。」で区切って1文ずつ並べる。「例：」で始まる文は例として囲む（サイトの TextPanel.svelte と同じ）
  static List<({bool example, String text})> _sentences(String summary) {
    final out = <({bool example, String text})>[];
    final re = RegExp(r'[^。]*。|[^。]+$');
    for (final m in re.allMatches(summary)) {
      final s = m.group(0)!.trim();
      if (s.isEmpty) continue;
      final ex = RegExp(r'^例[:：]\s*').firstMatch(s);
      out.add((example: ex != null, text: ex == null ? s : s.substring(ex.end)));
    }
    return out;
  }
}
