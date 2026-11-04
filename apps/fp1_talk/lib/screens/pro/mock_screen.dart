import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../items/item_set_screen.dart';
import '../pro_screen.dart';
import 'mock_result_screen.dart';

/// 模擬試験（Pro だけ）。FP1 は本試験と同じく基礎編（四答択一50問・150分）と応用編（設例5つ・150分）を別々に受ける。
/// GET /pro/mock で編ごとの組み方・予測点・記録、POST /pro/mock { section } で始め、解く画面は本試験形式と同じ（電卓つき）。
/// 予測点は 200点満点で合格の目安 120点。応用編の配点は公表されていないので推定（画面にそう書く）。
/// 広告は出さない（全画面広告も。試験の途中を切らないため）。
class MockIntroScreen extends StatefulWidget {
  const MockIntroScreen({super.key});

  @override
  State<MockIntroScreen> createState() => _MockIntroScreenState();
}

/// 「10/21 14:05」
String mockDate(Object? ms) {
  if (ms is! num) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _maps(Object? v) => ((v as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()).toList();

class _MockIntroScreenState extends State<MockIntroScreen> {
  Map<String, dynamic>? _d;
  Object? _error;
  String? _starting;

  ApiClient get _api => AppScope.read(context).api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.mockHistory();
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Map<String, dynamic> exam) async {
    final label = '${(exam['section'] as Map?)?['label'] ?? '模擬試験'}';
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemSetScreen.mock(mock: exam, label: label), settings: const RouteSettings(name: 'pro_mock_exam')));
    if (mounted) _load();
  }

  Future<void> _start(String section) async {
    setState(() => _starting = section);
    try {
      final d = await _api.startMock(section);
      AppInsights.logEvent('mock_start', parameters: {'section': section});
      if (!mounted) return;
      setState(() => _starting = null);
      await _open(d);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = null);
      if (e.code == 'pro_required') {
        await ProScreen.show(context, reason: 'mock');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  /// 解きかけ（制限時間のうち）を開き直す。書いた答えは残っていないので最初から
  Future<void> _resume(String id) async {
    try {
      final d = await _api.mockResult(id);
      if (mounted) await _open(d);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: const Text('模擬試験と予測点')),
      body: d == null
          ? Center(child: _error != null ? LoadError(error: _error!, onRetry: _load) : const CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _body(d)),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final plans = _maps(d['plans']);
    final history = _maps(d['history']);
    final open = _maps(d['open']);
    final forecast = (d['forecast'] as Map?)?.cast<String, dynamic>();
    final total = (d['scoreTotal'] as num?)?.toInt() ?? 200;
    final passLine = (d['passLine'] as num?)?.toInt() ?? 120;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Forecast(f: forecast, total: total, passLine: passLine, note: d['passLineNote'] as String?),
              const SizedBox(height: 20),
              const Text('本試験と同じ形式・時間で解く', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
              const SizedBox(height: 4),
              const Text('過去問から、まだ解いていない問・前にまちがえた問を優先して組みます。電卓は右上のボタンで出せます。時間が来たら、そこまでの答えで採点します。', style: TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft)),
              const SizedBox(height: 10),
              for (final p in plans) ...[
                _PlanCard(p: p, starting: _starting == p['key'], disabled: _starting != null, onStart: () => _start(p['key'] as String)),
                const SizedBox(height: 10),
              ],
              if (open.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('解きかけ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink)),
                const SizedBox(height: 6),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, o) in open.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text('${o['label'] ?? ''}（${mockDate(o['startedAt'])} に開始）'),
                        subtitle: Text('${mockDate(o['deadline'])} まで。書いた答えは残っていないので最初から'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _resume(o['id'] as String),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              const Text('これまでの結果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Text('まだありません。', style: Theme.of(context).textTheme.bodySmall)
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, h) in history.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _HistoryRow(
                        h: h,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MockResultScreen(id: h['id'] as String), settings: const RouteSettings(name: 'pro_mock_result'))),
                      ),
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

/// 予測点（200点満点・合格の目安 120点）と編ごと。まだ答えていなければ案内だけ
class _Forecast extends StatelessWidget {
  const _Forecast({required this.f, required this.total, required this.passLine, this.note});
  final Map<String, dynamic>? f;
  final int total;
  final int passLine;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final f = this.f;
    final score = (f?['score'] as num?)?.toInt();
    final good = score != null && score >= passLine;
    return Card(
      key: const Key('mock-forecast'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('いまの予測点（$total点満点・合格の目安 $passLine点）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
            if (f == null || score == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('本試験形式の問題や模擬試験に答えると、ここに予測点が出ます。', style: TextStyle(fontSize: 14, height: 1.6, color: Palette.ink)),
              )
            else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$score', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1.15, color: good ? Palette.success : Palette.primary)),
                Text(' / $total点', style: const TextStyle(fontSize: 16, color: Palette.inkSoft)),
                const SizedBox(width: 10),
                Flexible(child: Text('${f['low']}〜${f['high']}点（目安）', style: const TextStyle(fontSize: 13, color: Palette.inkSoft))),
              ]),
              Text(good ? '合格の目安に届いています' : '合格の目安まであと${passLine - score}点', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: good ? Palette.success : Palette.warning)),
              const SizedBox(height: 8),
              Row(children: [
                for (final (i, b) in _maps(f['bySection']).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${b['label']}${b['estimated'] == true ? '（配点は推定）' : ''}', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                        Text('${b['expected']} / ${b['max']}点', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Palette.ink)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ],
            if ((note ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('$note。応用編の点は推定の配点で数えた目安です。', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// 編ごとの組み方（基礎編: 四答択一50問・2点ずつ／応用編: 設例5つ・配点は推定）と「始める」
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.p, required this.starting, required this.disabled, required this.onStart});
  final Map<String, dynamic> p;
  final bool starting;
  final bool disabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isCase = p['kind'] == 'case';
    final planned = (p['planned'] as num?)?.toInt() ?? 0;
    final available = (p['available'] as num?)?.toInt() ?? 0;
    final missing = ((p['missing'] as List?) ?? const []).cast<String>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('${p['label']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink))),
              Text('${p['minutes']}分・${p['maxPoints']}点', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
            ]),
            const SizedBox(height: 2),
            Text(
              isCase ? '設例$planned題（1題に3問・空欄・計算）。分野ごとに設例を1つずつ' : '四答択一$planned問（1問2点）。分野ごとの出題数どおり',
              style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink),
            ),
            if (available < planned) Text('いまの教材で出せるのは ${isCase ? '設例$available題' : '$available問'}${missing.isEmpty ? '' : '（まだ無い分野: ${missing.join('・')}）'}', style: const TextStyle(fontSize: 12, color: Palette.warning)),
            if (p['estimated'] == true && (p['estimateNote'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('配点は推定: ${p['estimateNote']}', style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: Key('mock-start-${p['key']}'),
              onPressed: disabled || available == 0 ? null : onStart,
              icon: starting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.play_arrow),
              label: Text('${p['label']}を始める'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.h, required this.onTap});
  final Map<String, dynamic> h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = (h['score'] as num?)?.toInt() ?? 0;
    final passed = score >= ((h['passLine'] as num?)?.toInt() ?? 0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${h['label'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
              Text(mockDate(h['finishedAt']), style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
            ]),
          ),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink)),
            TextSpan(text: ' / ${h['max'] ?? 100}点', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
          ])),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(color: passed ? Palette.successSoft : Palette.fill, borderRadius: BorderRadius.circular(999)),
            child: Text(passed ? '目安に到達' : '届かず', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: passed ? Palette.success : Palette.inkSoft)),
          ),
          const Icon(Icons.chevron_right, color: Palette.inkFaint),
        ]),
      ),
    );
  }
}
