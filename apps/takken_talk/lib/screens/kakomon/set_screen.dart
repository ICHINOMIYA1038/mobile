import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../models/core.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/question_card.dart';
import '../../widgets/readable.dart';
import 'explain_sheet.dart';

/// 過去問を1問ずつ解く（サイトの /[exam]/kakomon/[set] のスマホの形）。答えたらその場で採点と解説、「次の問題」で進む。
/// 並びは本試験の順（問・肢）。「ランダム」で混ぜられる。最後まで行ったら、この回でまちがえた問題だけをもう一度解ける。
/// 「AIに聞く」は下からのシート。閉じれば同じ問題の同じ位置に戻る。
class KakomonSetScreen extends StatefulWidget {
  const KakomonSetScreen({super.key, required this.set, required this.label, this.mode = 'all'});
  final String set;
  final String label;

  /// all / new / wrong
  final String mode;

  @override
  State<KakomonSetScreen> createState() => _KakomonSetScreenState();
}

class _Item {
  _Item(Map<String, dynamic> j)
      : question = PublicQuestion.fromJson((j['question'] as Map).cast<String, dynamic>()),
        where = j['where'] as String? ?? '',
        answeredBefore = (j['state'] as Map?)?['answered'] == true,
        lastCorrect = (j['state'] as Map?)?['lastCorrect'] as bool?;
  final PublicQuestion question;
  final String where;
  final bool answeredBefore;
  final bool? lastCorrect;
}

const _modes = [('all', 'すべて'), ('new', 'まだ解いていない'), ('wrong', 'まちがえた')];

class _KakomonSetScreenState extends State<KakomonSetScreen> {
  late String _mode = widget.mode;
  List<_Item>? _items;
  List<Term> _glossary = const [];
  Object? _error;

  /// _items の添字の並び。ランダムにしても、まだ解いていない先の分だけを混ぜる
  List<int> _order = [];
  int _pos = 0;

  /// この画面を開いてから答えた問題
  final Map<String, Graded> _graded = {};
  bool _random = false;
  bool _sending = false;
  final _scroll = ScrollController();

  ApiClient get _api => AppScope.read(context).api;
  _Item? get _cur => _items != null && _pos < _order.length ? _items![_order[_pos]] : null;
  List<_Item> get _session => _order.map((i) => _items![i]).where((it) => _graded.containsKey(it.question.id)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final d = await _api.kakomonSet(widget.set, mode: _mode);
      if (!mounted) return;
      final items = ((d['items'] as List?) ?? const []).map((j) => _Item((j as Map).cast<String, dynamic>())).toList();
      setState(() {
        _items = items;
        _glossary = Term.listFrom(d['glossary']);
        _order = List.generate(items.length, (i) => i);
        _graded.clear();
        _random = false;
        // すべてのときは、まだ解いていない最初の問題から（続きから解ける）
        final first = _mode == 'all' ? items.indexWhere((it) => !it.answeredBefore) : -1;
        _pos = first > 0 ? first : 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _setMode(String m) {
    if (m == _mode) return;
    _mode = m;
    _load();
  }

  void _go(int to) {
    setState(() => _pos = to.clamp(0, _order.length));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _answer(bool a) async {
    final cur = _cur;
    if (cur == null || _graded.containsKey(cur.question.id) || _sending) return;
    final id = cur.question.id;
    setState(() => _sending = true);
    try {
      final j = await _api.answer(id, a);
      if (mounted) setState(() => _graded[id] = Graded.fromJson(j, answer: a));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送れませんでした。もう一度押してください。')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _shuffle() {
    setState(() {
      _random = !_random;
      final rest = _order.sublist(_pos);
      if (_random) {
        rest.shuffle(Random());
      } else {
        rest.sort();
      }
      _order = [..._order.sublist(0, _pos), ...rest];
    });
  }

  /// この回でまちがえた問題だけで、もう一度
  void _retryWrong() {
    final ids = _session.where((it) => !_graded[it.question.id]!.correct).map((it) => it.question.id).toSet();
    setState(() {
      _order = [for (var i = 0; i < _items!.length; i++) if (ids.contains(_items![i].question.id)) i];
      _graded.removeWhere((k, _) => ids.contains(k));
      _random = false;
    });
    _go(0);
  }

  void _restart() {
    setState(() {
      _order = List.generate(_items!.length, (i) => i);
      _graded.clear();
      _random = false;
    });
    _go(0);
  }

  void _ask() {
    final cur = _cur;
    if (cur == null) return;
    showExplainSheet(
      context,
      questionId: cur.question.id,
      statement: cur.question.statement,
      where: '${cur.where} について',
      graded: _graded[cur.question.id],
      glossary: _glossary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Text('過去問 ${widget.label}'),
        actions: [
          // 混ぜるのは、いまの問題から先だけ（解いた分の並びは変えない）
          if (items != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _Pill(
                label: _random ? 'ランダム中' : 'ランダム',
                selected: false,
                toggled: _random,
                onTap: _pos >= _order.length || _order.length < 2 ? null : _shuffle,
              ),
            ),
        ],
      ),
      body: items == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('読み込めませんでした。', style: TextStyle(color: Palette.inkSoft)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('もう一度')),
                    ]),
            )
          : Column(
              children: [
                _header(),
                Expanded(child: _body()),
                if (_cur != null) _stepBar(),
              ],
            ),
    );
  }

  Widget _header() {
    final n = _order.length;
    final cur = _cur;
    final filled = n == 0 ? 0.0 : min(_pos + (cur != null && _graded.containsKey(cur.question.id) ? 1 : 0), n) / n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Readable(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: '解く問題',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (key, label) in _modes) ...[
                    _Pill(label: label, selected: _mode == key, onTap: () => _setMode(key)),
                    const SizedBox(width: 6),
                  ],
                ]),
              ),
            ),
            if (n > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: filled),
                      duration: const Duration(milliseconds: 200),
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Palette.fillStrong, color: Palette.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${min(_pos + 1, n)} / $n', style: const TextStyle(fontSize: 13, color: Palette.inkSoft, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_order.isEmpty) {
      final msg = _mode == 'wrong' ? 'まちがえた問題はありません。' : _mode == 'new' ? 'この回の問題は全部解きました。' : 'この回の問題はまだありません。';
      return ListView(padding: const EdgeInsets.all(16), children: [
        Readable(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg, style: const TextStyle(color: Palette.inkSoft)),
              if (_mode != 'all')
                TextButton(
                  onPressed: () => _setMode('all'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
                  child: const Text('すべての問題へ'),
                ),
            ]),
          ),
        ),
      ]);
    }
    final cur = _cur;
    if (cur == null) return _result();
    final g = _graded[cur.question.id];
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Readable(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: cur.where),
                const TextSpan(text: ' の論点（文は作り直し）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Palette.inkFaint)),
                if (cur.answeredBefore && g == null) ...[
                  const TextSpan(text: ' '),
                  WidgetSpan(alignment: PlaceholderAlignment.middle, child: _Before(ok: cur.lastCorrect == true)),
                ],
              ]),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.primaryStrong),
            ),
            const SizedBox(height: 8),
            QuestionCard(
              key: ValueKey(cur.question.id),
              question: cur.question,
              graded: g,
              disabled: _sending,
              onAnswer: _answer,
              showOrigin: false,
              shownOn: 'kakomon',
              glossary: _glossary,
            ),
            const SizedBox(height: 10),
            const Text('わからないときは「AIに聞く」で、この問題を AI が解説します（答える前はヒントだけ）。', style: TextStyle(fontSize: 12, color: Palette.inkFaint)),
          ],
        ),
      ),
    );
  }

  Widget _result() {
    final session = _session;
    final right = session.where((it) => _graded[it.question.id]!.correct).length;
    final wrong = session.length - right;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      children: [
        const Text('おつかれさまでした', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '$right', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Palette.primary)),
            TextSpan(text: ' / ${session.length}問 正解'),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Palette.ink),
        ),
        const SizedBox(height: 20),
        Readable(
          maxWidth: 360,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wrong > 0) ...[
              FilledButton(onPressed: _retryWrong, child: Text('まちがえた $wrong問をもう一度')),
              const SizedBox(height: 10),
            ],
            OutlinedButton(onPressed: _restart, child: const Text('最初から')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('ほかの回を選ぶ')),
          ]),
        ),
      ],
    );
  }

  /// 前へ・AIに聞く・次へ。親指で押せるように画面の下に留める
  Widget _stepBar() {
    final cur = _cur!;
    final answered = _graded.containsKey(cur.question.id);
    final last = _pos + 1 >= _order.length;
    const shape = StadiumBorder();
    const label = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return Container(
      decoration: const BoxDecoration(color: Palette.desk, border: Border(top: BorderSide(color: Palette.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Readable(
            child: Row(
              children: [
                Semantics(
                  label: '前の問題へ',
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: _pos == 0 ? null : () => _go(_pos - 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: const BorderSide(color: Palette.lineStrong, width: 1.5),
                      foregroundColor: Palette.inkSoft,
                    ),
                    child: const Icon(Icons.chevron_left, size: 26),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ask,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: answered ? Palette.primarySoft : Palette.paper,
                      textStyle: label,
                    ),
                    child: const Text('AIに聞く'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: answered
                      ? FilledButton(
                          onPressed: () => _go(_pos + 1),
                          style: FilledButton.styleFrom(shape: shape, padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: Text(last ? '結果を見る ›' : '次の問題 ›'),
                        )
                      : OutlinedButton(
                          onPressed: () => _go(_pos + 1),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), backgroundColor: Palette.paper),
                          child: const Text('とばす ›'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 解く問題の切り替え（すべて・まだ解いていない・まちがえた）とランダム
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, this.toggled, this.onTap});
  final String label;
  final bool selected;

  /// ランダムのように押すたびに切り替わるもの（null なら選ぶもの）
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = selected || toggled == true;
    final fg = selected ? Colors.white : (on ? Palette.primary : Palette.inkSoft);
    return Semantics(
      button: true,
      selected: toggled == null ? selected : null,
      toggled: toggled,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Palette.primary : Palette.paper,
                border: Border.all(color: on ? Palette.primary : Palette.lineStrong),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Before extends StatelessWidget {
  const _Before({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: ok ? Palette.successSoft : Palette.dangerSoft, borderRadius: BorderRadius.circular(999)),
        child: Text(ok ? '前回 正解' : '前回 まちがえた', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ok ? Palette.success : Palette.danger)),
      );
}
