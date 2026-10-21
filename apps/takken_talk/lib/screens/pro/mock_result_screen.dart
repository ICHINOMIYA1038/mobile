import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../../widgets/rich_text.dart';
import '../common/parts.dart';
import 'mock_screen.dart';

/// 模擬試験の結果（`POST /pro/mock/<id>` の返り値か、記録から `GET /pro/mock/<id>`）。
/// 点数 → 合格点の目安との差 → 科目ごと → AI の講評 → 問題ごとの正誤（開くと解説と「この論点を先生と学ぶ」）。
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

  /// まちがえた問題だけ
  bool _wrongOnly = false;

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
    final shown = [for (final (i, it) in items.indexed) if (!_wrongOnly || it['correct'] != true) (i, it)];
    final wrong = items.where((it) => it['correct'] != true).length;
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
              Row(children: [
                const Expanded(child: Text('問題ごとの答え', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink))),
                if (wrong > 0)
                  FilterChip(
                    label: Text('まちがえた $wrong問だけ'),
                    selected: _wrongOnly,
                    onSelected: (v) => setState(() => _wrongOnly = v),
                    backgroundColor: Palette.paper,
                    selectedColor: Palette.primarySoft,
                    side: const BorderSide(color: Palette.lineStrong),
                  ),
              ]),
              const SizedBox(height: 8),
              for (final (i, it) in shown) ...[
                _ItemTile(n: i + 1, it: it),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
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

/// 1問ぶん。閉じているときは正誤と問題の文の頭、開くと答え・解説・根拠・「この論点を先生と学ぶ」
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.n, required this.it});
  final int n;
  final Map<String, dynamic> it;

  @override
  Widget build(BuildContext context) {
    final q = (it['question'] as Map?)?.cast<String, dynamic>() ?? const {};
    final correct = it['correct'] == true;
    final answer = it['answer'] as bool?;
    final right = it['correctAnswer'] as bool?;
    final chapterId = it['chapterId'] as String?;
    final pointId = it['pointId'] as String?;
    String ox(bool? a) => a == null ? '未回答' : (a ? '○' : '×');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: Icon(correct ? Icons.circle_outlined : Icons.close, color: correct ? Palette.hanamaru : Palette.danger, size: 26),
          title: Text('問$n  ${q['statement'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.5, color: Palette.ink)),
          subtitle: Text('あなたの答え ${ox(answer)}・正しい答え ${ox(right)}', style: TextStyle(fontSize: 12, color: correct ? Palette.inkSoft : Palette.danger)),
          children: [
            Text(q['statement'] as String? ?? '', style: const TextStyle(fontSize: 15, height: 1.7, color: Palette.ink)),
            if ((it['origin'] as String? ?? '').isNotEmpty) Text('${it['origin']} の論点（文は作り直し）', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
            const Divider(height: 20),
            if ((it['explanation'] as String? ?? '').isNotEmpty) RichBody(it['explanation'] as String, style: const TextStyle(fontSize: 15, height: 1.7, color: Palette.ink)),
            if ((it['reference'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('根拠: ${it['reference']}', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
            ],
            if (chapterId != null && chapterId.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openChapter(context, chapterId, pointId: pointId),
                icon: const Icon(Icons.forum_outlined, size: 20),
                label: const Text('この論点を先生と学ぶ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
