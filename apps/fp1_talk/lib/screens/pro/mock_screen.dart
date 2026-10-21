import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../pro_screen.dart';
import 'mock_result_screen.dart';

/// 模擬試験（Pro だけ。POST /pro/mock で始め、`POST /pro/mock/<id>` で答えを出す。サイトの src/lib/server/pro.ts）。
/// 本試験と同じ科目の比率で過去問の○×を50問、30分。答えは復習の記録にも入る。
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

class _MockIntroScreenState extends State<MockIntroScreen> {
  List<Map<String, dynamic>>? _history;
  bool _starting = false;

  ApiClient get _api => AppScope.read(context).api;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final d = await _api.mockHistory();
      if (mounted) setState(() => _history = ((d['history'] as List?) ?? const []).map((h) => (h as Map).cast<String, dynamic>()).toList());
    } catch (_) {
      // 記録が読めなくても試験は始められる
      if (mounted) setState(() => _history = const []);
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final d = await _api.startMock();
      if (!mounted) return;
      setState(() => _starting = false);
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MockExamScreen(exam: d), settings: const RouteSettings(name: 'pro_mock_exam')));
      if (mounted) _loadHistory();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      if (e.code == 'pro_required') {
        await ProScreen.show(context, reason: 'mock');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    return Scaffold(
      appBar: AppBar(title: const Text('模擬試験')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Readable(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('本番と同じ比率の模擬試験', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
                        const SizedBox(height: 4),
                        const Text('過去問の論点から作った○×を、まだ定着していない問題を優先して出します。時間が来たら、そこまでの答えで採点します。', style: TextStyle(fontSize: 14, height: 1.7, color: Palette.ink)),
                        const Divider(height: 24),
                        const Text('終わると科目ごとの点数と、AI の講評が出ます。答えは復習の記録にも入ります。', style: TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _starting ? null : _start,
                  icon: _starting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.play_arrow),
                  label: const Text('始める'),
                ),
                const SizedBox(height: 28),
                const Text('これまでの結果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
                const SizedBox(height: 8),
                if (history == null)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (history.isEmpty)
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
    final passed = score >= ((h['passLine'] as num?)?.toInt() ?? 36);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          Expanded(child: Text(mockDate(h['finishedAt']), style: const TextStyle(fontSize: 14, color: Palette.inkSoft))),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink)),
            TextSpan(text: ' / ${h['total'] ?? 50}点', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
          ])),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(color: passed ? Palette.successSoft : Palette.fill, borderRadius: BorderRadius.circular(999)),
            child: Text(passed ? '合格点' : '届かず', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: passed ? Palette.success : Palette.inkSoft)),
          ),
          const Icon(Icons.chevron_right, color: Palette.inkFaint),
        ]),
      ),
    );
  }
}

/// 試験の本体。1問ずつ○×を選ぶ。前へ・次へで行き来でき、「見直し」で番号の一覧から飛べる。
/// 時間が 0 になったら、そこまでの答えで自動で出す。戻るボタンでは「やめますか」と聞く（答えは残らない）。
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key, required this.exam});

  /// POST /pro/mock の返り値（id・seconds・passLine・questions）
  final Map<String, dynamic> exam;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late final String _id = widget.exam['id'] as String;
  late final int _limit = (widget.exam['seconds'] as num?)?.toInt() ?? 1800;
  late final List<Map<String, dynamic>> _qs = ((widget.exam['questions'] as List?) ?? const []).map((q) => (q as Map).cast<String, dynamic>()).toList();
  final Map<String, bool?> _answers = {};
  final _started = DateTime.now();
  Timer? _timer;
  int _pos = 0;
  bool _submitting = false;
  bool _timeUp = false;

  int get _elapsed => DateTime.now().difference(_started).inSeconds;
  int get _left => (_limit - _elapsed).clamp(0, _limit);
  int get _answered => _answers.values.where((a) => a != null).length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_left <= 0 && !_timeUp) {
        _timeUp = true;
        _timer?.cancel();
        _submit(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go(int to) => setState(() => _pos = to.clamp(0, _qs.length - 1));

  /// 選んだら少し置いて次へ（最後の問題では進まない）。戻って選び直せる
  void _choose(bool a) {
    if (_timeUp || _submitting) return;
    final at = _pos;
    setState(() => _answers[_qs[at]['id'] as String] = a);
    if (at < _qs.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted && _pos == at) _go(at + 1);
      });
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    if (!auto) {
      final rest = _qs.length - _answered;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('答えを出しますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Text(rest > 0 ? 'まだ答えていない問題が $rest問 あります（不正解として数えます）。出したあとは直せません。' : '出したあとは直せません。', style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('見直す')),
            FilledButton(key: const ValueKey('mock_submit_ok'), onPressed: () => Navigator.pop(ctx, true), child: const Text('答えを出す')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _submitting = true);
    final answers = {for (final q in _qs) q['id'] as String: _answers[q['id']]};
    try {
      final r = await AppScope.read(context).api.submitMock(_id, answers, _elapsed.clamp(0, _limit));
      _timer?.cancel();
      AppInsights.logEvent('mock_finish', parameters: {'score': (r['score'] as num?)?.toInt() ?? 0, 'total': (r['total'] as num?)?.toInt() ?? _qs.length, 'passed': r['passed'] == true ? 1 : 0, 'auto': auto ? 1 : 0});
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => MockResultScreen(result: r), settings: const RouteSettings(name: 'pro_mock_result')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.code == 'pro_required') {
        await ProScreen.show(context, reason: 'mock');
      } else {
        _sendFailed(e);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _sendFailed(e);
    }
  }

  void _sendFailed(Object e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(e)), duration: const Duration(seconds: 8), action: SnackBarAction(label: 'もう一度送る', onPressed: () => _submit(auto: true))),
      );

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('模擬試験をやめますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('ここまでの答えは残りません。', style: TextStyle(height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('続ける')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Palette.danger), child: const Text('やめる')),
        ],
      ),
    );
    if (quit == true && mounted) Navigator.of(context).pop();
  }

  /// 見直し: 番号の一覧（答えた・まだ）。押すとその問題へ
  void _review() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('見直し（答えた $_answered / ${_qs.length}問）', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Palette.ink)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _qs.length; i++)
                    _NumberCell(
                      n: i + 1,
                      answered: _answers[_qs[i]['id']] != null,
                      current: i == _pos,
                      onTap: () {
                        Navigator.pop(ctx);
                        _go(i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submit();
                },
                child: const Text('答えを出す'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _qs.isEmpty ? null : _qs[_pos];
    final a = q == null ? null : _answers[q['id']];
    final left = _left;
    final hurry = left < 5 * 60;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _confirmQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'やめる', icon: const Icon(Icons.close), onPressed: _submitting ? null : _confirmQuit),
          title: const Text('模擬試験'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: hurry ? Palette.dangerSoft : Palette.paper, border: Border.all(color: hurry ? Palette.danger : Palette.lineStrong), borderRadius: BorderRadius.circular(999)),
              child: Semantics(
                label: '残り時間',
                child: Text(
                  '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: hurry ? Palette.danger : Palette.ink, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ],
        ),
        body: q == null
            ? const Center(child: Text('問題を読み込めませんでした。'))
            : _submitting
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('採点して、AI が講評を書いています。\n10秒ほどお待ちください。', textAlign: TextAlign.center, style: TextStyle(color: Palette.inkSoft)),
                      ]),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Readable(
                          child: Row(children: [
                            Expanded(child: ProgressBar(value: _answered / _qs.length, height: 6)),
                            const SizedBox(width: 10),
                            Text('${_pos + 1}/${_qs.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()])),
                          ]),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Readable(child: _QuestionPaper(q: q, n: _pos + 1)),
                        ),
                      ),
                      if (_timeUp)
                        const Padding(padding: EdgeInsets.all(8), child: Text('時間になりました。', style: TextStyle(color: Palette.danger, fontWeight: FontWeight.w700))),
                      _answerBar(a),
                    ],
                  ),
      ),
    );
  }

  Widget _answerBar(bool? a) {
    final last = _pos >= _qs.length - 1;
    return Container(
      decoration: const BoxDecoration(color: Palette.desk, border: Border(top: BorderSide(color: Palette.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Readable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _OxButton(key: const ValueKey('mock_true'), label: '○ 正しい', selected: a == true, onTap: () => _choose(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _OxButton(key: const ValueKey('mock_false'), label: '× 誤り', selected: a == false, onTap: () => _choose(false))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Semantics(
                    label: '前の問題へ',
                    excludeSemantics: true,
                    child: OutlinedButton(
                      onPressed: _pos == 0 ? null : () => _go(_pos - 1),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(52, 44), padding: const EdgeInsets.symmetric(horizontal: 14), side: const BorderSide(color: Palette.lineStrong, width: 1.5), foregroundColor: Palette.inkSoft),
                      child: const Icon(Icons.chevron_left, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('mock_review'),
                      onPressed: _review,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44), backgroundColor: Palette.paper, padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text('見直し $_answered/${_qs.length}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: last
                        ? FilledButton(key: const ValueKey('mock_submit'), onPressed: () => _submit(), style: FilledButton.styleFrom(minimumSize: const Size(64, 44)), child: const Text('答えを出す'))
                        : OutlinedButton(
                            onPressed: () => _go(_pos + 1),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44), backgroundColor: Palette.paper, padding: const EdgeInsets.symmetric(horizontal: 8)),
                            child: Text(a == null ? 'とばす ›' : '次へ ›'),
                          ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 問題の用紙（科目・番号・出典と、問題の文）
class _QuestionPaper extends StatelessWidget {
  const _QuestionPaper({required this.q, required this.n});
  final Map<String, dynamic> q;
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
          child: Row(children: [
            Text('問$n', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.primaryStrong)),
            const SizedBox(width: 8),
            Expanded(child: Text('${q['subject'] ?? ''}・${q['topic'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary))),
          ]),
        ),
        const SizedBox(height: 10),
        Text(q['statement'] as String? ?? '', style: const TextStyle(fontSize: 17, height: 1.8, color: Palette.ink)),
        if ((q['origin'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${q['origin']} の論点（文は作り直し）', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
        ],
      ],
    ),
  );
}

class _OxButton extends StatelessWidget {
  const _OxButton({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? Palette.primary : Palette.paper,
      shape: RoundedRectangleBorder(side: BorderSide(color: selected ? Palette.primary : Palette.lineStrong, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 60,
          child: Center(child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: selected ? Colors.white : Palette.ink))),
        ),
      ),
    ),
  );
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.n, required this.answered, required this.current, required this.onTap});
  final int n;
  final bool answered;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '問$n ${answered ? '答えた' : 'まだ'}',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered ? Palette.primarySoft : Palette.paper,
          border: Border.all(color: current ? Palette.primary : (answered ? Palette.primarySoft : Palette.lineStrong), width: current ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$n', style: TextStyle(fontSize: 14, fontWeight: answered ? FontWeight.w700 : FontWeight.w400, color: answered ? Palette.primaryStrong : Palette.inkSoft)),
      ),
    ),
  );
}
