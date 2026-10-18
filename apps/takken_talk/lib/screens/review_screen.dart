import 'package:flutter/material.dart';

import '../main.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/question_card.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 復習（サイトの /takken/review）。あとで復習 / 前回まちがえた / 復習の時期 の3つ。
/// 答えは POST answer で採点する（AI を使わないので、1日に話せる回数は減らない）。
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
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _answer(String id, bool a) async {
    setState(() => _sending.add(id));
    try {
      final j = await AppScope.read(context).api.answer(id, a);
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

  Widget _body(Map<String, List<_Item>> lists) {
    final (key, _, empty) = _tabs[_tab];
    final items = lists[key] ?? const [];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: items.isEmpty ? 2 : items.length + 1,
      itemBuilder: (context, i) {
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
                        label: Text('${_tabs[t].$2} ${lists[_tabs[t].$1]?.length ?? 0}', maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
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
        if (items.isEmpty) return Readable(child: _Empty(text: empty));
        final it = items[i - 1];
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
          '過去問を解くか、先生と話して○×に答えると、復習する問題がたまっていきます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Palette.inkFaint),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(onPressed: () => Shell.select(context, 1), icon: const Icon(Icons.fact_check_outlined), label: const Text('過去問を解く')),
            OutlinedButton.icon(onPressed: () => Shell.select(context, 0), icon: const Icon(Icons.forum_outlined), label: const Text('先生と学ぶ')),
          ],
        ),
      ],
    ),
  );
}
