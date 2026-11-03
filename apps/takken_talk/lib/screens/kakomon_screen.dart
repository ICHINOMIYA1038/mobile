import 'package:flutter/material.dart';

import '../ads/ad_banner.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';

/// 過去問演習の一覧（サイトの /[exam]/kakomon と同じ並び）。回ごと・科目ごとに、解いた数と正解の数を出す。
/// 解く画面から戻ったら数え直す（下のタブで残り続ける画面なので、開いたときの数のままにしない）。
class KakomonScreen extends StatefulWidget {
  const KakomonScreen({super.key});

  @override
  State<KakomonScreen> createState() => _KakomonScreenState();
}

class _KakomonScreenState extends State<KakomonScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  /// 章ごと（「学ぶ」のカリキュラムの順）・回ごと・科目ごと
  String _by = 'chapter';

  /// タブが見えているか。隠れ→見えを「タブを開いた」とみなして数え直す（ほかの画面で解いた分・データの削除を映す）
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
    if (visible && !_visible && _data != null) _load();
    _visible = visible;
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.kakomonIndex();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(_SetRow s, {String mode = 'all'}) async {
    await openKakomon(context, set: s.key, label: s.label, mode: mode);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      // Pro でない人にだけ、一覧の下にバナー（下のタブの上）
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(title: const Text('過去問演習')),
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('読み込めませんでした。', style: TextStyle(color: Palette.inkSoft)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('もう一度')),
                    ]),
            )
          : RefreshIndicator(onRefresh: _load, child: _list(d)),
    );
  }

  Widget _list(Map<String, dynamic> d) {
    final all = _SetRow.from(d['all']);
    final exams = ((d['exams'] as List?) ?? const []).map(_SetRow.from).toList();
    final subjects = ((d['subjects'] as List?) ?? const []).map(_SetRow.from).toList();
    final chapters = ((d['chapters'] as List?) ?? const []).cast<Map>();
    // 古いサーバー（chapters が無い）では章ごとを出さない
    final by = chapters.isEmpty && _by == 'chapter' ? 'exam' : _by;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '本試験（平成27〜令和7年度）の選択肢を1つずつ、○×の問題にしました。問題の文は当サイトで作り直し、出典の年度・問・肢を付けています。答え合わせはその場で済み、1日に話せる回数は減りません。',
                style: TextStyle(fontSize: 14, height: 1.7, color: Palette.inkSoft),
              ),
              if (all.total == 0)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(4)),
                  child: const Text('過去問の問題を準備しています。もうしばらくお待ちください。', style: TextStyle(color: Palette.inkSoft)),
                )
              else ...[
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    if (chapters.isNotEmpty) const ButtonSegment(value: 'chapter', label: Text('章ごと')),
                    const ButtonSegment(value: 'exam', label: Text('回ごと')),
                    const ButtonSegment(value: 'subject', label: Text('科目ごと')),
                  ],
                  selected: {by},
                  onSelectionChanged: (v) => setState(() => _by = v.first),
                ),
                const SizedBox(height: 12),
                if (by == 'chapter') ...[
                  const Text('「学ぶ」の章と同じ分け方です。会話で学んだ章の過去問を、論点の順に解けます。', style: TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft)),
                  for (final (i, c) in chapters.indexed) ...[
                    if (i == 0 || chapters[i - 1]['subject'] != c['subject']) _Heading(c['subject'] as String? ?? '', top: i == 0 ? 12 : 20),
                    _Row(_SetRow.from(c), onOpen: _open),
                  ],
                ] else if (by == 'exam') ...[
                  for (final s in exams) _Row(s, onOpen: _open),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('同じ論点が何年も出ているものは1問にまとめています。', style: TextStyle(fontSize: 13, color: Palette.inkSoft)),
                  ),
                  for (final s in subjects) _Row(s, onOpen: _open),
                  _Row(all, onOpen: _open),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SetRow {
  const _SetRow(this.key, this.label, this.total, this.answered, this.correct);
  final String key;
  final String label;
  final int total;
  final int answered;
  final int correct;

  static _SetRow from(Object? v) {
    final j = (v as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return _SetRow(j['key'] as String? ?? 'all', j['label'] as String? ?? '', n('total'), n('answered'), n('correct'));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.top = 24});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
      );
}

/// 1行目に回の名前と問題数、2行目に進み具合の線と数字。まちがえた問題があれば、その問題だけを解く入口を下に
class _Row extends StatelessWidget {
  const _Row(this.s, {required this.onOpen});
  final _SetRow s;
  final void Function(_SetRow s, {String mode}) onOpen;

  @override
  Widget build(BuildContext context) {
    final wrong = s.answered - s.correct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onOpen(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text(s.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink))),
                      Text('${s.total}問', style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                    ]),
                    const SizedBox(height: 8),
                    Semantics(
                      label: '解いた ${s.answered}/${s.total}問',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.total == 0 ? 0 : s.answered / s.total,
                          minHeight: 6,
                          backgroundColor: Palette.fillStrong,
                          color: Palette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.answered > 0 ? '解いた ${s.answered}・正解 ${s.correct}' : 'まだ解いていない',
                      style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
            if (wrong > 0)
              InkWell(
                onTap: () => onOpen(s, mode: 'wrong'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
                  child: Text('まちがえた $wrong問', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.danger)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
