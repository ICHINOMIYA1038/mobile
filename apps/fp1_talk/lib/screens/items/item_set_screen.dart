import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/calculator.dart';
import '../../widgets/exam_text.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../kakomon/explain_sheet.dart';
import '../pro/mock_result_screen.dart';

/// 本試験形式の問題を1問ずつ解く（サイトの /fp1/items/<まとまり> と同じ。サイトの docs/question-formats.md の 5.）。
/// - 四答択一: 押したらすぐ答え合わせ。正解の番号と、選択肢ごとの解説
/// - 空欄・計算: 欄を埋めて（数字は数字のキーボード、単位は欄の横）「答え合わせ」。欄ごとの正誤・模範の計算過程・合っていた途中の値
/// - 応用編は設例を上に（折りたためる）。表は横にスクロール
/// - 電卓は右上のボタンでいつでも出せる（閉じても値は残る）
///
/// - 模擬試験（mock）: 答え合わせはせずに選ぶ・書くだけ。上に残り時間、「答えを出す」でまとめて採点（時間が来たら自動で出す）
/// - 模擬試験の見直し（review）: 結果の答え・正解・解説を1問ずつ（AIに聞く もできる）
///
/// 計算に集中する画面なので広告は出さない。
class ItemSetScreen extends StatefulWidget {
  const ItemSetScreen({super.key, required this.set, required this.label, this.startAt = 0}) : mock = null, review = null;

  /// 模擬試験を解く（POST /pro/mock の返り値: id・deadline・now・items・cases）
  const ItemSetScreen.mock({super.key, required Map<String, dynamic> this.mock, required this.label}) : set = '', review = null, startAt = 0;

  /// 模擬試験の結果を1問ずつ見る（`POST /pro/mock/<id>` の返り値。items[].response・result）
  const ItemSetScreen.review({super.key, required Map<String, dynamic> this.review, required this.label, this.startAt = 0}) : set = '', mock = null;

  final String set;
  final String label;
  final Map<String, dynamic>? mock;
  final Map<String, dynamic>? review;
  final int startAt;

  @override
  State<ItemSetScreen> createState() => _ItemSetScreenState();
}

const _choiceFormats = {'choice', 'count', 'combination'};
const _ask = {
  'most-appropriate': '最も適切なもの',
  'least-appropriate': '最も不適切なもの',
  'correct': '正しいもの',
  'incorrect': '誤っているもの',
  'count': '個数',
  'combination': '組合せ',
};

class _ItemSetScreenState extends State<ItemSetScreen> {
  Map<String, dynamic>? _data;
  Object? _error;
  int _pos = 0;
  bool _sending = false;
  Object? _sendError;
  bool _caseOpen = true;
  bool _calcOpen = false;
  final _calc = CalculatorController();
  final _scroll = ScrollController();

  /// 問題 id → 採点の結果
  final Map<String, Map<String, dynamic>> _results = {};

  /// 問題 id → 答え合わせに送ったもの（「AIに聞く」に渡す。正解・解説はサーバーが入れる）
  final Map<String, Map<String, Object>> _sent = {};

  /// 問題 id → 欄の label → 入力欄（答え・計算過程）。問題を行き来しても書いたものは残す
  final Map<String, Map<String, TextEditingController>> _inputs = {};
  final Map<String, Map<String, TextEditingController>> _process = {};

  /// 選択肢から選ぶ欄（kind: option）の答え
  final Map<String, Map<String, String>> _picked = {};

  /// 模擬試験で選んだ番号（答え合わせはしない）
  final Map<String, int> _choice = {};
  Timer? _timer;

  /// サーバーの時計との差（残り時間はサーバーの deadline から数える）
  Duration _skew = Duration.zero;
  final _opened = DateTime.now();
  bool _submitting = false;

  bool get _isMock => widget.mock != null;
  bool get _isReview => widget.review != null;

  @override
  void initState() {
    super.initState();
    if (widget.mock case final m?) {
      _data = m;
      final now = (m['now'] as num?)?.toInt();
      if (now != null) _skew = DateTime.fromMillisecondsSinceEpoch(now).difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (widget.review case final r?) {
      _data = r;
      _pos = widget.startAt;
      for (final it in _items) {
        final id = it['id'] as String;
        final res = (it['result'] as Map?)?.cast<String, dynamic>();
        final resp = (it['response'] as Map?)?.cast<String, dynamic>();
        if (res != null) _results[id] = res;
        if (resp != null) _sent[id] = resp.map((k, v) => MapEntry(k, v as Object));
        for (final pr in ((res?['parts'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>())) {
          final label = pr['label'] as String;
          final part = _parts(it).where((x) => x['label'] == label).firstOrNull;
          if (part?['kind'] == 'option') {
            (_picked[id] ??= {})[label] = pr['response'] as String? ?? '';
          } else {
            _ctl(_inputs, id, label).text = pr['response'] as String? ?? '';
          }
          final proc = ((resp?['process'] as Map?)?[label] as List?)?.cast<String>();
          if (proc != null) _ctl(_process, id, label).text = proc.join('\n');
        }
      }
    } else {
      _load();
    }
  }

  // ---------- 模擬試験 ----------

  int get _deadline => (widget.mock?['deadline'] as num?)?.toInt() ?? 0;
  int get _leftSec => ((_deadline - DateTime.now().add(_skew).millisecondsSinceEpoch) / 1000).ceil().clamp(0, 1 << 30);

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_leftSec <= 0 && !_submitting) _submit(timeUp: true);
  }

  static String _clock(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(h > 0 ? 2 : 1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 答えた問か（四答択一は選んだ、書く問はどれかの欄を書いた）
  bool _answeredInMock(Map<String, dynamic> it) {
    final id = it['id'] as String;
    if (_choiceFormats.contains(it['format'])) return _choice[id] != null;
    return _parts(it).any((p) => p['kind'] == 'option' ? (_picked[id]?[p['label']] ?? '').isNotEmpty : (_inputs[id]?[p['label']]?.text.trim().isNotEmpty ?? false));
  }

  Map<String, Object> _mockAnswers() {
    final out = <String, Object>{};
    for (final it in _items) {
      final id = it['id'] as String;
      if (!_answeredInMock(it)) continue;
      if (_choiceFormats.contains(it['format'])) {
        out[id] = {'choice': _choice[id]!};
        continue;
      }
      final parts = <String, String>{};
      final process = <String, List<String>>{};
      for (final p in _parts(it)) {
        final label = p['label'] as String;
        parts[label] = p['kind'] == 'option' ? (_picked[id]?[label] ?? '') : _ctl(_inputs, id, label).text;
        if (p['showProcess'] == true) process[label] = _ctl(_process, id, label).text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      }
      out[id] = {'parts': parts, if (process.isNotEmpty) 'process': process};
    }
    return out;
  }

  Future<void> _submit({bool timeUp = false}) async {
    if (_submitting) return;
    final blank = _items.where((it) => !_answeredInMock(it)).length;
    if (!timeUp) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('答えを出しますか？'),
          content: Text(blank == 0 ? 'すべての問に答えています。採点します。' : 'まだ答えていない問が $blank問 あります。このまま採点しますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('続ける')),
            FilledButton(key: const Key('mock-submit-ok'), onPressed: () => Navigator.pop(ctx, true), child: const Text('答えを出す')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    _timer?.cancel();
    final api = AppScope.read(context).api;
    final nav = Navigator.of(context);
    try {
      final r = await api.submitMock(widget.mock!['id'] as String, _mockAnswers(), DateTime.now().difference(_opened).inSeconds);
      AppInsights.logEvent('mock_finish', parameters: {'section': (widget.mock?['section'] as Map?)?['key']?.toString() ?? '', 'score': (r['score'] as num?) ?? 0});
      if (!mounted) return;
      await nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => MockResultScreen(result: r), settings: const RouteSettings(name: 'pro_mock_result')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (_leftSec > 0) _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  /// 問の番号の一覧（答えた問に印）。押すとその問へ
  void _showList() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, it) in _items.indexed)
              SizedBox(
                width: 52,
                height: 44,
                child: OutlinedButton(
                  key: Key('mock-jump-${i + 1}'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _isMock && _answeredInMock(it) ? Palette.primarySoft : _results[it['id']]?['correct'] == false ? Palette.dangerSoft : null,
                    side: BorderSide(color: i == _pos ? Palette.primary : Palette.lineStrong, width: i == _pos ? 2 : 1),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _go(i);
                  },
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('模擬試験をやめますか？'),
        content: const Text('書いた答えは残りません。制限時間のあいだは、模擬試験の画面の「解きかけ」から最初の状態でやり直せます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('続ける')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('やめる', style: TextStyle(color: Palette.danger))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  void dispose() {
    for (final m in [..._inputs.values, ..._process.values]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    _calc.dispose();
    _scroll.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.itemSet(widget.set);
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          final n = ((d['items'] as List?) ?? const []).length;
          if (_pos == 0 && widget.startAt > 0 && n > 0) _pos = widget.startAt.clamp(0, n - 1);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Map<String, dynamic>> get _items => ((_data?['items'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  TextEditingController _ctl(Map<String, Map<String, TextEditingController>> store, String id, String label) =>
      (store[id] ??= {})[label] ??= TextEditingController();

  void _go(int to) {
    final n = _items.length;
    setState(() {
      _pos = to.clamp(0, n - 1);
      _sendError = null;
    });
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _send(Map<String, dynamic> it, {int? choice}) async {
    if (_sending) return;
    final id = it['id'] as String;
    final parts = <String, String>{};
    final process = <String, List<String>>{};
    if (choice == null) {
      for (final p in _parts(it)) {
        final label = p['label'] as String;
        parts[label] = p['kind'] == 'option' ? (_picked[id]?[label] ?? '') : _ctl(_inputs, id, label).text;
        if (p['showProcess'] == true) {
          process[label] = _ctl(_process, id, label).text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        }
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final r = await AppScope.read(context).api.itemAnswer(id, choice: choice, parts: choice == null ? parts : null, process: choice == null && process.isNotEmpty ? process : null);
      AppInsights.logEvent('item_answer', parameters: {'format': it['format'] as String? ?? '', 'correct': r['correct'] == true ? 1 : 0});
      if (mounted) {
        setState(() {
          _results[id] = r;
          _sent[id] = {'choice': ?choice, if (choice == null) 'parts': parts, if (choice == null && process.isNotEmpty) 'process': process};
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sendError = e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static List<Map<String, dynamic>> _parts(Map<String, dynamic> it) => ((it['parts'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final d = _data;
    final left = _isMock ? _leftSec : 0;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: _isMock
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('残り ${_clock(left)}', key: const Key('mock-clock'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: left < 600 ? Palette.danger : Palette.inkSoft, fontFeatures: const [FontFeature.tabularFigures()])),
              ])
            : Text(widget.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_isMock || _isReview)
            IconButton(
              key: const Key('mock-list'),
              tooltip: '問の一覧',
              onPressed: _showList,
              icon: const Icon(Icons.grid_view),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          IconButton(
            key: const Key('calc-toggle'),
            tooltip: _calcOpen ? '電卓を閉じる' : '電卓を出す',
            isSelected: _calcOpen,
            onPressed: () => setState(() => _calcOpen = !_calcOpen),
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          if (_isMock)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                key: const Key('mock-submit'),
                onPressed: _submitting ? null : () => _submit(),
                style: FilledButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('答えを出す'),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
      body: d == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : LoadError(error: _error!, onRetry: _load))
          : items.isEmpty
              ? const Center(child: Text('このまとまりには問題がありません。', style: TextStyle(color: Palette.inkSoft)))
              : Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        // 数字のキーボードには「完了」が無いので、欄の外を押したら閉じる
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.translucent,
                        child: ListView(
                          controller: _scroll,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          children: [Readable(child: _question(items[_pos.clamp(0, items.length - 1)], items.length))],
                        ),
                      ),
                    ),
                    if (_calcOpen)
                      Material(
                        color: Palette.paper,
                        elevation: 8,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: Readable(maxWidth: 420, child: CalculatorPad(controller: _calc, onClose: () => setState(() => _calcOpen = false))),
                          ),
                        ),
                      ),
                  ],
                ),
    );
    if (!_isMock) return scaffold;
    // 戻るでは「やめますか」と聞く（答えは残らない）
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _submitting) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) {
          _timer?.cancel();
          nav.pop();
        }
      },
      child: scaffold,
    );
  }

  Widget _question(Map<String, dynamic> it, int total) {
    final id = it['id'] as String;
    final res = _results[id];
    final isChoice = _choiceFormats.contains(it['format']);
    final cases = (_data?['cases'] as Map?)?.cast<String, dynamic>() ?? const {};
    final theCase = it['caseId'] != null ? (cases[it['caseId']] as Map?)?.cast<String, dynamic>() : null;
    final chapterLabel = ((_data?['chapters'] as Map?)?[it['chapterId']] as String?) ?? (it['chapter'] as String?) ?? '';
    final answered = _isMock ? _items.where(_answeredInMock).length : _items.where((x) => _results.containsKey(x['id']) || x['lastScore'] != null).length;
    final points = ((it['points'] as List?) ?? const []).fold<num>(0, (a, b) => a + (b as num));
    final estimated = (_data?['section'] as Map?)?['estimated'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('${_pos + 1} / $total問', key: const Key('item-pos'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
          const SizedBox(width: 8),
          Text('（答えた $answered問）', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
          const Spacer(),
          if (points > 0)
            Text(
              _isReview && it['earned'] != null ? '${it['earned']} / $points点${estimated ? '（推定）' : ''}' : '配点 $points点${estimated ? '（推定）' : ''}',
              style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
            ),
        ]),
        const SizedBox(height: 8),
        if (theCase != null) ...[_case(theCase), const SizedBox(height: 12)],
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 8, runSpacing: 2, children: [
                  if (chapterLabel.isNotEmpty) Text(chapterLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
                  if ((it['subject'] as String?)?.isNotEmpty == true && _isMock) Text(it['subject'] as String, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  if (it['origin'] != null) Text('出典: ${it['origin']}', style: const TextStyle(fontSize: 11, color: Palette.inkFaint)),
                ]),
                const SizedBox(height: 8),
                if (isChoice && _ask[it['ask']] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${_ask[it['ask']]}を選ぶ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.warning)),
                  ),
                ExamText(it['stem'] as String? ?? ''),
                if ((it['material'] as String?)?.isNotEmpty == true) ExamText(it['material'] as String, small: true),
                if ((it['figure'] as String?)?.isNotEmpty == true) _note('図の内容', it['figure'] as String),
                if (isChoice) ..._options(it, res) else ..._partsForm(it, res),
                if (_sendError != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText(_sendError!), style: const TextStyle(color: Palette.danger))),
              ],
            ),
          ),
        ),
        if (res != null) ...[const SizedBox(height: 12), _result(it, res, isChoice)],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _pos == 0 ? null : () => _go(_pos - 1), child: const Text('前の問題'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(key: const Key('item-next'), onPressed: _pos >= total - 1 ? null : () => _go(_pos + 1), child: const Text('次の問題'))),
        ]),
      ],
    );
  }

  Widget _case(Map<String, dynamic> c) => Card(
        clipBehavior: Clip.antiAlias,
        color: Palette.fill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('case-toggle'),
              onTap: () => setState(() => _caseOpen = !_caseOpen),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(children: [
                  Expanded(child: Text('《設例》${c['title'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink))),
                  Text(_caseOpen ? '閉じる' : '開く', style: const TextStyle(fontSize: 13, color: Palette.primary)),
                  Icon(_caseOpen ? Icons.expand_less : Icons.expand_more, color: Palette.primary),
                ]),
              ),
            ),
            if (_caseOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ExamText(c['setting'] as String? ?? '', small: true),
                  if ((c['figure'] as String?)?.isNotEmpty == true) _note('図の内容', c['figure'] as String),
                ]),
              ),
          ],
        ),
      );

  Widget _note(String head, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(6)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$head  ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text),
          ]), style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.ink)),
        ),
      );

  // ---------- 四答択一 ----------

  List<Widget> _options(Map<String, dynamic> it, Map<String, dynamic>? res) {
    final options = ((it['options'] as List?) ?? const []).cast<String>();
    final notes = ((res?['optionNotes'] as List?) ?? const []).map((e) => e?.toString()).toList();
    final answer = (res?['answer'] as num?)?.toInt();
    final chose = (res?['choice'] as num?)?.toInt();
    return [
      const SizedBox(height: 4),
      for (final (i, o) in options.indexed) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _OptionButton(
            key: Key('option-${i + 1}'),
            no: i + 1,
            text: o,
            state: _isMock
                ? (_choice[it['id']] == i + 1 ? _Opt.selected : _Opt.idle)
                : res == null
                ? _Opt.idle
                : answer == i + 1
                    ? _Opt.right
                    : chose == i + 1
                        ? _Opt.wrong
                        : _Opt.dim,
            mark: _isMock
                ? (_choice[it['id']] == i + 1 ? '選んだ答え' : null)
                : res == null
                ? null
                : answer == i + 1
                ? '正解'
                : chose == i + 1
                ? 'あなたの答え'
                : null,
            onTap: _isMock
                ? (_submitting ? null : () => setState(() => _choice[it['id'] as String] = i + 1))
                : res != null || _sending
                ? null
                : () => _send(it, choice: i + 1),
          ),
        ),
        if (i < notes.length && (notes[i] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 6, 4, 2),
            child: Text(notes[i]!, style: const TextStyle(fontSize: 13.5, height: 1.65, color: Palette.ink)),
          ),
      ],
    ];
  }

  // ---------- 空欄・計算・表 ----------

  List<Widget> _partsForm(Map<String, dynamic> it, Map<String, dynamic>? res) {
    final id = it['id'] as String;
    final results = {for (final r in ((res?['parts'] as List?) ?? const [])) (r as Map)['label'] as String: r.cast<String, dynamic>()};
    final parts = _parts(it);
    return [
      if ((it['instructions'] as String?)?.isNotEmpty == true && it['format'] != 'calc')
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(it['instructions'] as String, style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft))),
      const Divider(height: 20),
      for (final p in parts) _partField(id, p, results[p['label']], locked: res != null || _isReview || _submitting),
      if (res == null && !_isMock && !_isReview)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            key: const Key('item-grade'),
            onPressed: _sending ? null : () => _send(it),
            child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('答え合わせ'),
          ),
        ),
    ];
  }

  Widget _partField(String id, Map<String, dynamic> p, Map<String, dynamic>? r, {required bool locked}) {
    final label = p['label'] as String;
    final kind = p['kind'] as String? ?? 'word';
    final numeric = kind == 'number' || kind == 'amount';
    final unit = p['unit'] as String?;
    final rounding = p['rounding'] as String?;
    final options = ((p['options'] as List?) ?? const []).cast<String>();
    final ok = r?['ok'] == true;
    final color = r == null ? Palette.line : ok ? Palette.success : Palette.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: r == null ? 1 : 1.5),
        borderRadius: BorderRadius.circular(8),
        color: r == null ? null : ok ? Palette.successSoft : Palette.dangerSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 34, child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink))),
            Expanded(
              child: kind == 'option' && options.isNotEmpty
                  ? Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final o in options)
                        ChoiceChip(
                          label: Text(o),
                          selected: _picked[id]?[label] == _optionKey(o),
                          onSelected: locked ? null : (_) => setState(() => (_picked[id] ??= {})[label] = _optionKey(o)),
                        ),
                    ])
                  : TextField(
                      key: Key('part-$label'),
                      controller: _ctl(_inputs, id, label),
                      enabled: !locked,
                      onChanged: _isMock ? (_) => setState(() {}) : null,
                      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 17, fontFeatures: [FontFeature.tabularFigures()]),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Palette.paper,
                        hintText: numeric ? '数字' : '語句',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
            ),
            if (unit != null && unit.isNotEmpty)
              Padding(padding: const EdgeInsets.only(left: 8), child: Text(unit, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink))),
          ]),
          if (rounding != null && rounding.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4),
              child: Text('端数: $rounding', style: const TextStyle(fontSize: 12, color: Palette.warning)),
            ),
          if (p['showProcess'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                key: Key('process-$label'),
                controller: _ctl(_process, id, label),
                enabled: !locked,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  labelText: '〔計算過程〕途中の値を1行ずつ',
                  hintText: '例: 816,000×480/480＝816,000',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Palette.paper,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (r != null) ..._partVerdict(r),
        ],
      ),
    );
  }

  /// 「イ．…」「1 …」の頭の記号を答えにする（サイトと同じ）
  static String _optionKey(String o) => o.split(RegExp(r'[\s．.：:]')).first;

  List<Widget> _partVerdict(Map<String, dynamic> r) {
    final ok = r['ok'] == true;
    final matched = ((r['matchedSteps'] as List?) ?? const []).cast<String>();
    final steps = ((r['steps'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final unit = r['unit'] as String?;
    return [
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: ok ? '正解' : '不正解', style: TextStyle(fontWeight: FontWeight.w800, color: ok ? Palette.success : Palette.danger)),
          if (!ok) ...[
            const TextSpan(text: '　正しい答え '),
            TextSpan(text: '${_num(r['answer']?.toString() ?? '')}${unit ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
          if ((r['unitNote'] as String?)?.isNotEmpty == true) TextSpan(text: '（${r['unitNote']}）', style: const TextStyle(color: Palette.warning)),
          if (r['unreadable'] == true) const TextSpan(text: '（数字として読めませんでした）', style: TextStyle(color: Palette.warning)),
        ]),
        style: const TextStyle(fontSize: 15, height: 1.6, color: Palette.ink),
      ),
      if (r.containsKey('matchedSteps'))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            r['upTo'] != null
                ? '計算過程は「${r['upTo']}」まで合っています。'
                : matched.isNotEmpty
                    ? '途中の値のうち ${matched.join('・')} が合っています。'
                    : '計算過程の途中の値は、模範の値と合いませんでした。',
            style: const TextStyle(fontSize: 13.5, height: 1.6, color: Palette.ai, fontWeight: FontWeight.w600),
          ),
        ),
      if ((r['process'] as String?)?.isNotEmpty == true || steps.isNotEmpty)
        // 色の付いた欄の上に置くので Material を挟む（ListTile の押した跡が隠れないように）
        Material(
          type: MaterialType.transparency,
          child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('model-${r['label']}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: const Text('模範の計算過程', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.primary)),
            children: [
              if ((r['process'] as String?)?.isNotEmpty == true)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(r['process'] as String, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final s in steps)
                  Row(children: [
                    Icon(matched.contains(s['label']) ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: matched.contains(s['label']) ? Palette.success : Palette.inkFaint),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${s['label']}  ${_num('${s['value']}')}', style: const TextStyle(fontSize: 13.5, height: 1.6))),
                  ]),
              ],
            ],
          ),
        ),
        ),
    ];
  }

  /// 数字だけの答えは桁区切りにする（「797874」→「797,874」）
  static String _num(String v) {
    final m = RegExp(r'^(-?)(\d+)(\.\d+)?$').firstMatch(v);
    if (m == null) return v;
    final i = m.group(2)!.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${m.group(1)}$i${m.group(3) ?? ''}';
  }

  Widget _result(Map<String, dynamic> it, Map<String, dynamic> res, bool isChoice) {
    final correct = res['correct'] == true;
    final n = _parts(it).length;
    final score = (res['score'] as num?)?.toDouble() ?? 0;
    return Container(
      key: const Key('item-result'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: correct ? Palette.successSoft : Palette.paper,
        border: Border.all(color: correct ? Palette.success : Palette.lineStrong),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            correct ? '正解' : isChoice ? '不正解（正解は ${res['answer']}）' : '${(score * n).round()} / $n欄 正解',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: correct ? Palette.success : Palette.danger),
          ),
          if ((res['explanation'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(res['explanation'] as String, style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (!_isReview)
              TextButton.icon(
                onPressed: () => setState(() => _results.remove(it['id'])),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('もう一度解く'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
            TextButton.icon(
              key: const Key('item-ask'),
              onPressed: _sent[it['id']] == null ? null : () => _askAi(it, res),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('AIに聞く'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
            // 本試験形式で分からなかった章を、AI の先生と学び直す
            if (it['chapterId'] is String)
              TextButton.icon(
                key: const Key('item-learn'),
                onPressed: () => openChapter(context, it['chapterId'] as String),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('この章を先生と学ぶ'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
          ]),
        ],
      ),
    );
  }
}

extension on _ItemSetScreenState {
  /// 答え合わせのあと、その問（設例・自分の答え・正解・解説）を文脈に AI に聞く
  void _askAi(Map<String, dynamic> it, Map<String, dynamic> res) {
    final id = it['id'] as String;
    final sent = _sent[id];
    if (sent == null) return;
    final chapterLabel = ((_data?['chapters'] as Map?)?[it['chapterId']] as String?) ?? '';
    final stem = (it['stem'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    showItemExplainSheet(
      context,
      itemId: id,
      statement: stem,
      where: '${widget.label}${chapterLabel.isEmpty ? '' : '・$chapterLabel'}',
      answer: ExplainAnswer.fromItem(res, sent),
    );
  }
}

enum _Opt { idle, right, wrong, dim, selected }

class _OptionButton extends StatelessWidget {
  const _OptionButton({super.key, required this.no, required this.text, required this.state, this.mark, this.onTap});
  final int no;
  final String text;
  final _Opt state;
  final String? mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border) = switch (state) {
      _Opt.right => (Palette.successSoft, Palette.success),
      _Opt.wrong => (Palette.dangerSoft, Palette.danger),
      _Opt.selected => (Palette.primarySoft, Palette.primary),
      _ => (Palette.paper, Palette.lineStrong),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: state == _Opt.idle || state == _Opt.dim ? 1 : 2)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: state == _Opt.right ? Palette.success : state == _Opt.wrong ? Palette.danger : state == _Opt.selected ? Palette.primary : Palette.primarySoft),
              child: Text('$no', style: TextStyle(fontWeight: FontWeight.w800, color: state == _Opt.right || state == _Opt.wrong || state == _Opt.selected ? Colors.white : Palette.primaryStrong)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(text, style: TextStyle(fontSize: 15, height: 1.65, color: state == _Opt.dim ? Palette.inkSoft : Palette.ink)),
                if (mark != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(mark!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: state == _Opt.right ? Palette.success : state == _Opt.selected ? Palette.primary : Palette.danger)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
