import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../../widgets/rich_text.dart';
import '../common/parts.dart';
import 'mock_screen.dart';

/// 模擬試験の結果（`POST /pro/mock/<id>` の返り値か、記録から `GET /pro/mock/<id>`）。
/// 点数 → 合格点の目安との差 → 科目ごと → AI の講評 → 問題ごとの正誤（すべて・まちがえた・未回答で絞り、押すと1問ずつの画面で前へ・次へ）。
class MockResultScreen extends StatefulWidget {
  const MockResultScreen({super.key, this.result, this.id}) : assert(result != null || id != null);
  final Map<String, dynamic>? result;
  final String? id;

  @override
  State<MockResultScreen> createState() => _MockResultScreenState();
}

class _MockResultScreenState extends State<MockResultScreen> {
  late Map<String, dynamic>? _r = widget.result;
  Object? _error;

  /// 問題の一覧の絞り込み: all / wrong（まちがえた。未回答も含む）/ blank（未回答）
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    if (_r == null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await AppScope.read(context).api.mockResult(widget.id!);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text(r == null ? '模擬試験の結果' : '模擬試験の結果  ${mockDate(r['finishedAt'])}')),
      body: r == null ? Center(child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator()) : _body(r),
    );
  }

  Widget _body(Map<String, dynamic> r) {
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final total = (r['total'] as num?)?.toInt() ?? 50;
    final passLine = (r['passLine'] as num?)?.toInt() ?? 36;
    final passed = r['passed'] == true;
    final seconds = (r['seconds'] as num?)?.toInt();
    final bySubject = ((r['bySubject'] as List?) ?? const []).cast<Map>();
    final items = ((r['items'] as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()).toList();
    final shown = mockFilter(items, _filter);
    final counts = {for (final f in const ['all', 'wrong', 'blank']) f: mockFilter(items, f).length};
    final review = (r['review'] as String? ?? '').trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$score', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: passed ? Palette.success : Palette.primary, height: 1.1)),
                  TextSpan(text: ' / $total点', style: const TextStyle(fontSize: 20, color: Palette.inkSoft)),
                ]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: passed ? Palette.successSoft : Palette.warningSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    passed ? '合格点の目安（$passLine点）に届きました' : '合格点の目安（$passLine点）まで あと${passLine - score}点',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: passed ? Palette.success : Palette.warning),
                  ),
                ),
              ),
              if (seconds != null) ...[
                const SizedBox(height: 6),
                Text('かかった時間 ${seconds ~/ 60}分${seconds % 60}秒', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
              ],
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(children: [
                    for (final s in bySubject) _SubjectScore(label: s['label'] as String? ?? '', correct: (s['correct'] as num?)?.toInt() ?? 0, total: (s['total'] as num?)?.toInt() ?? 0),
                  ]),
                ),
              ),
              if (review.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(color: Palette.aiSoft, border: Border.all(color: Palette.ai.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Row(children: [
                      Icon(Icons.auto_awesome, size: 18, color: Palette.ai),
                      SizedBox(width: 6),
                      Text('AI の講評', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.ai)),
                    ]),
                    const SizedBox(height: 6),
                    RichBody(review, style: const TextStyle(fontSize: 15, height: 1.8, color: Palette.ink)),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              const Text('問題ごとの答え', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
              const Text('押すと問題文・解説・根拠を1問ずつ見られます。', style: TextStyle(fontSize: 13, color: Palette.inkSoft)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (f, label) in const [('all', 'すべて'), ('wrong', 'まちがえた'), ('blank', '未回答')])
                  ChoiceChip(
                    key: ValueKey('mock_filter_$f'),
                    label: Text('$label ${counts[f]}'),
                    selected: _filter == f,
                    onSelected: counts[f] == 0 && f != 'all' ? null : (_) => setState(() => _filter = f),
                    backgroundColor: Palette.paper,
                    selectedColor: Palette.primarySoft,
                    side: const BorderSide(color: Palette.lineStrong),
                  ),
              ]),
              const SizedBox(height: 8),
              if (shown.isEmpty) const Text('ありません。', style: TextStyle(color: Palette.inkSoft)),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (k, (i, it)) in shown.indexed) ...[
                    if (k > 0) const Divider(height: 1),
                    _ItemRow(n: i + 1, it: it, onTap: () => _openItem(shown, k)),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 1問ずつの画面（いまの絞り込みの中を前へ・次へで動く）
  void _openItem(List<(int, Map<String, dynamic>)> list, int at) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MockItemScreen(items: list, index: at), settings: const RouteSettings(name: 'pro_mock_item')),
  );
}

/// 結果の絞り込み。番号（0 始まり）と問題の組で返す
List<(int, Map<String, dynamic>)> mockFilter(List<Map<String, dynamic>> items, String filter) => [
  for (final (i, it) in items.indexed)
    if (filter == 'all' || (filter == 'wrong' && it['correct'] != true) || (filter == 'blank' && it['answer'] == null)) (i, it),
];

String _ox(bool? a) => a == null ? '未回答' : (a ? '○' : '×');

/// 一覧の1行: 正誤の印・番号・問題の文の頭・答え
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.n, required this.it, required this.onTap});
  final int n;
  final Map<String, dynamic> it;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = (it['question'] as Map?)?.cast<String, dynamic>() ?? const {};
    final correct = it['correct'] == true;
    final blank = it['answer'] == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(children: [
          Icon(correct ? Icons.circle_outlined : (blank ? Icons.remove : Icons.close), color: correct ? Palette.hanamaru : (blank ? Palette.inkFaint : Palette.danger), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('問$n  ${q['statement'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.5, color: Palette.ink)),
              Text('あなたの答え ${_ox(it['answer'] as bool?)}・正しい答え ${_ox(it['correctAnswer'] as bool?)}', style: TextStyle(fontSize: 12, color: correct ? Palette.inkSoft : Palette.danger)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Palette.inkFaint),
        ]),
      ),
    );
  }
}

/// 1問ずつ: 問題文（全文）・○ 正しい / × 誤り（自分の答えと正しい答えに色）・正誤・解説・根拠・出典・「この論点を先生と学ぶ」。前へ・次へ
class MockItemScreen extends StatefulWidget {
  const MockItemScreen({super.key, required this.items, required this.index});

  /// 絞り込んだ問題（番号と問題）
  final List<(int, Map<String, dynamic>)> items;
  final int index;

  @override
  State<MockItemScreen> createState() => _MockItemScreenState();
}

class _MockItemScreenState extends State<MockItemScreen> {
  late int _at = widget.index;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int to) {
    setState(() => _at = to.clamp(0, widget.items.length - 1));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final (i, it) = widget.items[_at];
    final q = (it['question'] as Map?)?.cast<String, dynamic>() ?? const {};
    final answer = it['answer'] as bool?;
    final right = it['correctAnswer'] as bool?;
    final correct = it['correct'] == true;
    final chapterId = it['chapterId'] as String?;
    final origin = it['origin'] as String? ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('問${i + 1}（${_at + 1}/${widget.items.length}）')),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(q['topic'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary))),
                    Text(answer == null ? '未回答' : (correct ? '正解' : '不正解'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: answer == null ? Palette.inkSoft : (correct ? Palette.hanamaru : Palette.danger))),
                  ]),
                  const Divider(height: 16),
                  Text(q['statement'] as String? ?? '', style: const TextStyle(fontSize: 17, height: 1.8, color: Palette.ink)),
                  if (origin.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('出典: $origin の論点（文は作り直し）', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Choice(label: '○ 正しい', mine: answer == true, right: right == true)),
                const SizedBox(width: 10),
                Expanded(child: _Choice(label: '× 誤り', mine: answer == false, right: right == false)),
              ]),
              if (answer == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('この問題は未回答でした。', style: TextStyle(fontSize: 13, color: Palette.inkSoft))),
              const SizedBox(height: 16),
              const Text('解説', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
              const SizedBox(height: 4),
              RichBody(it['explanation'] as String? ?? '', style: const TextStyle(fontSize: 15, height: 1.8, color: Palette.ink)),
              if ((it['reference'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('根拠: ${it['reference']}', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
              ],
              if (chapterId != null && chapterId.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => openChapter(context, chapterId, pointId: it['pointId'] as String?),
                  icon: const Icon(Icons.forum_outlined, size: 20),
                  label: const Text('この論点を先生と学ぶ'),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Palette.desk, border: Border(top: BorderSide(color: Palette.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Expanded(child: OutlinedButton(key: const ValueKey('mock_item_prev'), onPressed: _at == 0 ? null : () => _go(_at - 1), style: OutlinedButton.styleFrom(backgroundColor: Palette.paper), child: const Text('‹ 前へ'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(key: const ValueKey('mock_item_next'), onPressed: _at >= widget.items.length - 1 ? null : () => _go(_at + 1), child: const Text('次へ ›'))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ○ / × の札。正しい答えは緑、自分がまちがえて選んだほうは赤
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.mine, required this.right});
  final String label;
  final bool mine;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = right ? (Palette.success, Palette.successSoft, Palette.success) : (mine ? (Palette.danger, Palette.dangerSoft, Palette.danger) : (Palette.inkSoft, Palette.paper, Palette.lineStrong));
    final note = [if (mine) 'あなたの答え', if (right) '正しい答え'].join('・');
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: right || mine ? 2 : 1), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: fg)),
        if (note.isNotEmpty) Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

class _SubjectScore extends StatelessWidget {
  const _SubjectScore({required this.label, required this.correct, required this.total});
  final String label;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0.0 : correct / total;
    final color = rate < 0.6 ? Palette.danger : rate < 0.7 ? Palette.warning : Palette.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink))),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$correct', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            TextSpan(text: ' / $total', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
          ])),
        ]),
        const SizedBox(height: 4),
        ProgressBar(value: rate, color: color, height: 8),
      ]),
    );
  }
}
