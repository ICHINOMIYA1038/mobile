import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/figure_card.dart';
import '../widgets/figure_search.dart';

/// 図解の一覧。会話しなくても体系をつかめる場所。
/// [chapter] を渡すとその章だけ、渡さないと全章を横断して探せる。
class FigureLibraryScreen extends StatefulWidget {
  const FigureLibraryScreen({super.key, this.chapter});
  final Chapter? chapter;

  @override
  State<FigureLibraryScreen> createState() => _FigureLibraryScreenState();
}

class _FigureLibraryScreenState extends State<FigureLibraryScreen> {
  final _search = TextEditingController();
  List<Figure>? _figures;
  final _hay = <String, String>{};
  String? _error;
  String? _kind;
  String? _subject;
  String _query = '';

  bool get _wholeLibrary => widget.chapter == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final api = AppScope.of(context).api;
      final f = widget.chapter == null ? await api.allFigures() : await api.figures(widget.chapter!.id);
      for (final x in f) {
        _hay[x.id] = figureHaystack(x);
      }
      if (mounted) setState(() => _figures = f);
      AppInsights.logEvent('figures_open', parameters: {'scope': _wholeLibrary ? 'all' : widget.chapter!.id});
    } catch (_) {
      if (mounted) setState(() => _error = '図解を読み込めませんでした');
    }
  }

  List<Figure> get _shown {
    final all = _figures ?? const <Figure>[];
    final q = _query.trim().toLowerCase();
    final me = AppScope.of(context).me;
    return all.where((f) {
      if (_kind != null && f.kind != _kind) return false;
      if (_subject != null && me?.chapter(f.chapterId)?.subject != _subject) return false;
      if (q.isNotEmpty && !(_hay[f.id] ?? '').contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = AppScope.of(context).me!;
    final all = _figures;
    final shown = _shown;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_wholeLibrary ? '図解ライブラリ' : '第${widget.chapter!.order}章の図解', style: theme.textTheme.titleMedium),
            if (!_wholeLibrary) Text(widget.chapter!.short, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
      body: all == null
          ? Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(_error!), const SizedBox(height: 8), TextButton(onPressed: _load, child: const Text('再読み込み'))],
                    )
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                _Filters(
                  figures: all,
                  wholeLibrary: _wholeLibrary,
                  subjects: me.subjects,
                  chapterOf: (id) => me.chapter(id),
                  kind: _kind,
                  subject: _subject,
                  controller: _search,
                  onKind: (k) => setState(() => _kind = k),
                  onSubject: (s) => setState(() => _subject = s),
                  onQuery: (q) => setState(() => _query = q),
                  shownCount: shown.length,
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('該当する図解がありません。\n検索語を短くするか、絞り込みを外してみてください。',
                                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          children: [
                            ..._sections(context, shown, me),
                            const SizedBox(height: 20),
                            Text('図解の内容は事前に用意したもので、AIが生成したものではありません。数字や法改正はテキストでも確認してください。',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.5)),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  /// 全章のときは章ごとに見出しを挟む。1章だけのときは並べるだけ。
  List<Widget> _sections(BuildContext context, List<Figure> shown, Me me) {
    final theme = Theme.of(context);
    if (!_wholeLibrary) {
      return [
        for (final f in shown) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(f.hint, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ),
          FigureCard(figure: f),
        ],
      ];
    }
    final out = <Widget>[];
    for (final c in me.chapters) {
      final mine = shown.where((f) => f.chapterId == c.id).toList();
      if (mine.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 3, height: 15, margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Text('第${c.order}章 ${c.short}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text('${mine.length}枚', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ));
      for (final f in mine) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(f.hint, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ));
        out.add(FigureCard(figure: f));
      }
    }
    return out;
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.figures,
    required this.wholeLibrary,
    required this.subjects,
    required this.chapterOf,
    required this.kind,
    required this.subject,
    required this.controller,
    required this.onKind,
    required this.onSubject,
    required this.onQuery,
    required this.shownCount,
  });
  final List<Figure> figures;
  final bool wholeLibrary;
  final List<Subject> subjects;
  final Chapter? Function(String) chapterOf;
  final String? kind;
  final String? subject;
  final TextEditingController controller;
  final ValueChanged<String?> onKind;
  final ValueChanged<String?> onSubject;
  final ValueChanged<String> onQuery;
  final int shownCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '中身を検索（例: 保証金、2週間、農地）',
                hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          controller.clear();
                          onQuery('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(context, 'すべての型', kind == null, () => onKind(null)),
                for (final k in FigureKind.all)
                  if (figures.any((f) => f.kind == k.key))
                    _chip(context, '${k.label} ${figures.where((f) => f.kind == k.key).length}', kind == k.key,
                        () => onKind(kind == k.key ? null : k.key)),
              ],
            ),
          ),
          if (wholeLibrary && subjects.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(context, '全科目', subject == null, () => onSubject(null)),
                  for (final s in subjects)
                    _chip(context, '${s.name} ${s.examQuestions}問', subject == s.name,
                        () => onSubject(subject == s.name ? null : s.name)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              shownCount == figures.length ? '全${figures.length}枚' : '$shownCount枚を表示中（全${figures.length}枚）',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
          labelStyle: Theme.of(context).textTheme.labelMedium,
          showCheckmark: false,
        ),
      );
}
