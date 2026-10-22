import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../items/item_set_screen.dart';
import 'mock_screen.dart';

/// 模擬試験の結果（`POST /pro/mock/<id>` の返り値か、記録から `GET /pro/mock/<id>`。形はサイトの itemmock.ts の itemMockResult）。
/// 点数（編の満点）→ 合格点の目安との差 → 分野ごとの点 → 講評 → 問ごとの答え（すべて・まちがえた・未回答で絞り、
/// 押すと本試験形式の画面で問題・自分の答え・正解・解説・模範の計算過程を1問ずつ。AIに聞く もできる）。
/// 応用編の点は推定の配点（画面にそう書く）。
class MockResultScreen extends StatefulWidget {
  const MockResultScreen({super.key, this.result, this.id}) : assert(result != null || id != null);
  final Map<String, dynamic>? result;
  final String? id;

  @override
  State<MockResultScreen> createState() => _MockResultScreenState();
}

/// 問の一覧の絞り込み: all / wrong（すべての欄が合ったわけではない。未回答も含む）/ blank（未回答）。返すのは（元の位置, 問）
List<(int, Map<String, dynamic>)> mockFilter(List<Map<String, dynamic>> items, String filter) => [
  for (final (i, it) in items.indexed)
    if (filter == 'all' || (filter == 'wrong' && (it['result'] as Map?)?['correct'] != true) || (filter == 'blank' && it['response'] == null)) (i, it),
];

class _MockResultScreenState extends State<MockResultScreen> {
  late Map<String, dynamic>? _r = widget.result;
  Object? _error;
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
    final label = (r?['section'] as Map?)?['label'] as String? ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(r == null ? '模擬試験の結果' : '$label の結果  ${mockDate(r['finishedAt'])}')),
      body: r == null ? Center(child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator()) : _body(r),
    );
  }

  void _openItem(Map<String, dynamic> r, int index) {
    final label = '${(r['section'] as Map?)?['label'] ?? ''}の見直し';
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemSetScreen.review(review: r, label: label, startAt: index), settings: const RouteSettings(name: 'pro_mock_review')));
  }

  Widget _body(Map<String, dynamic> r) {
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final max = (r['max'] as num?)?.toInt() ?? 100;
    final passLine = (r['passLine'] as num?)?.toInt() ?? 60;
    final passed = r['passed'] == true;
    final seconds = (r['seconds'] as num?)?.toInt();
    final section = (r['section'] as Map?)?.cast<String, dynamic>() ?? const {};
    final estimated = section['estimated'] == true;
    final bySubject = ((r['bySubject'] as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()).toList();
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
                  TextSpan(text: ' / $max点', style: const TextStyle(fontSize: 20, color: Palette.inkSoft)),
                ]),
                key: const Key('mock-score'),
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
              const SizedBox(height: 6),
              Text(
                '合格点の目安は本試験（200点満点で120点）の6割を、この編の満点に当てはめたものです。${estimated ? '応用編の配点は公表されていないため推定です。' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft),
              ),
              if (seconds != null) ...[
                const SizedBox(height: 4),
                Text('かかった時間 ${seconds ~/ 60}分${seconds % 60}秒（制限 ${section['minutes'] ?? 150}分）', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
              ],
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(children: [
                    for (final s in bySubject) _SubjectScore(s: s),
                  ]),
                ),
              ),
              if (review.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('講評（記録から）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary)),
                    const SizedBox(height: 6),
                    Text(review, style: const TextStyle(fontSize: 15, height: 1.8, color: Palette.ink)),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              const Text('問ごとの答え', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
              const Text('押すと問題・あなたの答え・正解・解説を1問ずつ見られます（AIに聞く もできます）。答えた問は復習にも入ります。', style: TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (f, label) in const [('all', 'すべて'), ('wrong', 'まちがえた'), ('blank', '未回答')])
                  ChoiceChip(label: Text('$label ${counts[f]}'), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
              ]),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (k, (i, it)) in shown.indexed) ...[
                    if (k > 0) const Divider(height: 1),
                    _ItemRow(no: i + 1, it: it, onTap: () => _openItem(r, i)),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectScore extends StatelessWidget {
  const _SubjectScore({required this.s});
  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final points = (s['points'] as num?)?.toInt() ?? 0;
    final max = (s['max'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(s['label'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink))),
          Text('$points / $max点', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
          SizedBox(width: 72, child: Text('（${s['correct'] ?? 0}/${s['total'] ?? 0}問）', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Palette.inkSoft))),
        ]),
        const SizedBox(height: 4),
        ProgressBar(value: max == 0 ? 0 : points / max, height: 6),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.no, required this.it, required this.onTap});
  final int no;
  final Map<String, dynamic> it;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final res = (it['result'] as Map?)?.cast<String, dynamic>();
    final blank = it['response'] == null;
    final correct = res?['correct'] == true;
    final parts = (res?['parts'] as List?) ?? const [];
    final pts = ((it['points'] as List?) ?? const []).fold<num>(0, (a, b) => a + (b as num));
    final stem = (it['stem'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final verdict = blank
        ? '未回答'
        : parts.isEmpty
        ? (correct ? '正解' : '不正解（${res?['choice']}→正解 ${res?['answer']}）')
        : '${parts.where((p) => (p as Map)['ok'] == true).length}/${parts.length}欄';
    final color = blank ? Palette.inkFaint : correct ? Palette.success : Palette.danger;
    return InkWell(
      key: Key('mock-item-$no'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 34,
            child: Icon(blank ? Icons.remove_circle_outline : correct ? Icons.check_circle : Icons.cancel, color: color, size: 22),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('問$no  ${it['subject'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
              Text(stem, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.5, color: Palette.ink)),
              Text('$verdict・${it['earned'] ?? 0}/$pts点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Palette.inkFaint),
        ]),
      ),
    );
  }
}
