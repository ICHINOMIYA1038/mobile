import 'package:flutter/material.dart';

import '../ads/ad_banner.dart';
import '../main.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/question_card.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 復習（サイトの /fp1/review）。あとで復習 / 前回まちがえた / 復習の時期 の3つ。
/// 答えは POST answer で採点する（AI を使わないので、1日に話せる回数は減らない）。
/// 「まちがえた」の上には、本試験形式（過去問・模擬試験）で前回まちがえた問（GET review の items）を出し、
/// 押すとその問から、「まとめて解き直す」で全部を、本試験形式の画面（items/wrong）で解き直す。
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _Item {
  const _Item({required this.question, required this.chapterId, required this.chapterLabel, this.point});
  final PublicQuestion question;
  final String chapterId;
  final String chapterLabel;
  final String? point;

  factory _Item.fromJson(Map<String, dynamic> j) {
    final c = (j['chapter'] as Map).cast<String, dynamic>();
    return _Item(
      question: PublicQuestion.fromJson((j['question'] as Map).cast<String, dynamic>()),
      chapterId: c['id'] as String,
      chapterLabel: '第${c['order']}章 ${c['short']}',
      point: j['point'] as String?,
    );
  }

  static List<_Item> listFrom(Object? v) => ((v as List?) ?? const []).map((e) => _Item.fromJson((e as Map).cast<String, dynamic>())).toList();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _tabs = [('bookmarks', 'あとで復習', '○×カードの「☆ あとで復習」を押すと、ここに集まります。'), ('wrong', 'まちがえた', '前回まちがえた問題はありません。'), ('due', '復習の時期', '今日もう一度解く時期の問題はありません。')];

  Map<String, List<_Item>>? _lists;

  /// 本試験形式で前回まちがえた問（{ id, format, sectionLabel, caseTitle, chapter, origin, text, lastScore }）
  List<Map<String, dynamic>> _wrongItems = const [];
  String _itemSet = 'wrong';
  Object? _error;
  int _tab = 0;

  /// この画面で答えた結果。取り直しても残す（答えた直後にカードが消えないように）
  final Map<String, Graded> _graded = {};
  final Set<String> _sending = {};

  /// タブが見えているか。IndexedStack は見えないタブを Visibility で隠すので、隠れ→見えを「タブを開いた」とみなす
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = Visibility.of(context);
    if (visible && !_visible && _lists != null) _load();
    _visible = visible;
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.review();
      if (!mounted) return;
      setState(() {
        _lists = {for (final t in _tabs) t.$1: _Item.listFrom(d[t.$1])};
        _wrongItems = ((d['items'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
        _itemSet = d['itemSet'] as String? ?? 'wrong';
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _answer(String id, bool a) async {
    setState(() => _sending.add(id));
    try {
      final j = await AppScope.read(context).api.answer(id, a, via: 'review');
      if (mounted) setState(() => _graded[id] = Graded.fromJson(j, answer: a));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _sending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = _lists;
    return Scaffold(
      // Pro でない人にだけ、一覧の下にバナー（下のタブの上）
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: const Text('復習', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: lists == null
          ? Center(
              child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_load(), AppScope.read(context).refresh()]);
              },
              child: _body(lists),
            ),
    );
  }

  /// 本試験形式の画面で解き直す。戻ったら一覧を取り直す（合えば消える）
  Future<void> _solveItems({int startAt = 0}) async {
    await openItems(context, set: _itemSet, label: '本試験形式でまちがえた問', startAt: startAt);
    if (mounted) _load();
  }

  Widget _itemsSection() => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Card(
      key: const Key('review-items'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Expanded(child: Text('本試験形式でまちがえた問 ${_wrongItems.length}問', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink))),
              FilledButton(key: const Key('review-items-solve'), onPressed: () => _solveItems(), child: const Text('まとめて解き直す')),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text('過去問演習・模擬試験で、すべての欄が合わなかった問。解き直して合えば消えます。', style: TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
          ),
          for (final (i, it) in _wrongItems.take(8).indexed) ...[
            const Divider(height: 1),
            InkWell(
              key: Key('review-item-$i'),
              onTap: () => _solveItems(startAt: i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        [
                          if ((it['chapter'] as Map?) case final c?) '第${c['order']}章 ${c['short']}',
                          if (it['sectionLabel'] != null) it['sectionLabel'],
                          if (it['caseTitle'] != null) '《設例》${it['caseTitle']}',
                        ].join('・'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary),
                      ),
                      Text(it['text'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.5, color: Palette.ink)),
                      Text(
                        '${(it['format'] == 'choice' || it['format'] == 'count' || it['format'] == 'combination') ? '四答択一' : '欄 ${(((it['lastScore'] as num?) ?? 0) * 100).round()}% 正解'}${_sitting(it['origin']) == null ? '' : '・${_sitting(it['origin'])}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Palette.inkFaint),
                      ),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Palette.inkFaint),
                ]),
              ),
            ),
          ],
          if (_wrongItems.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Text('ほか ${_wrongItems.length - 8}問は「まとめて解き直す」から', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
            ),
        ],
      ),
    ),
  );

  Widget _body(Map<String, List<_Item>> lists) {
    final (key, _, empty) = _tabs[_tab];
    final items = lists[key] ?? const [];
    // 「まちがえた」の上に本試験形式の問（○×が無くても出す）
    final withItems = key == 'wrong' && _wrongItems.isNotEmpty;
    final head = withItems ? 2 : 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: items.isEmpty ? 2 : items.length + head,
      itemBuilder: (context, i) {
        if (withItems && i == 1) return Readable(child: _itemsSection());
        if (i == 0) {
          return Readable(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ここで答えた結果も、間隔をあけて出し直す記録に反映されます。答え合わせはこの場で済み、1日に話せる回数は減りません。', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var t = 0; t < _tabs.length; t++)
                      ButtonSegment(
                        value: t,
                        label: Text('${_tabs[t].$2} ${(lists[_tabs[t].$1]?.length ?? 0) + (_tabs[t].$1 == 'wrong' ? _wrongItems.length : 0)}', maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                      ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    selectedBackgroundColor: Palette.primarySoft,
                    selectedForegroundColor: Palette.primaryStrong,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
        if (items.isEmpty) return withItems ? const SizedBox.shrink() : Readable(child: _Empty(text: empty));
        final it = items[i - head];
        return Readable(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => openChapter(context, it.chapterId),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      child: Text(it.chapterLabel),
                    ),
                    if (it.point != null) Text(it.point!, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                  ],
                ),
                QuestionCard(question: it.question, graded: _graded[it.question.id], disabled: _sending.contains(it.question.id), onAnswer: (a) => _answer(it.question.id, a), shownOn: 'review'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 出典の文（「一般社団法人… 2026年9月 問1」）から回と問の番号だけ（「2026年9月 問1」）
String? _sitting(Object? origin) => origin is String ? RegExp(r'\d{4}年\d{1,2}月 問\d+').firstMatch(origin)?.group(0) : null;

/// 空のとき。問題が集まる場所（過去問・学ぶ）へ案内する
class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 40, color: Palette.inkFaint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Palette.inkSoft),
        ),
        const SizedBox(height: 4),
        const Text(
          '先生と話して○×に答えると、復習する問題がたまっていきます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Palette.inkFaint),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(onPressed: () => Shell.select(context, 0), icon: const Icon(Icons.forum_outlined), label: const Text('先生と学ぶ')),
            OutlinedButton.icon(onPressed: () => Shell.select(context, 1), icon: const Icon(Icons.edit_note_outlined), label: const Text('本試験形式を解く')),
          ],
        ),
      ],
    ),
  );
}
