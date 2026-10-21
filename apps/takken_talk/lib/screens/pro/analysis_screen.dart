import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../pro_screen.dart';

/// 苦手分析と学習プラン（GET /pro/analysis。サイトの src/lib/server/pro.ts）。
/// Pro: AI のプラン（方針・まずやること・7日の目安）→ 科目ごとの正答率 → 苦手な論点 → まだ手をつけていない章。
/// Pro でない人（pro: false）: 科目ごとの正答率だけ見せ、Pro で何が増えるかを伝えて Pro の案内へ。
/// 広告は出さない（Pro の機能の画面なので）。
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  /// プランを作り直しているあいだ（AI が書くので 10 秒ほど）
  bool _remaking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _data = null;
        _error = null;
      });
    }
    try {
      final d = await AppScope.read(context).api.proAnalysis();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  Future<void> _remake() async {
    setState(() => _remaking = true);
    try {
      final d = await AppScope.read(context).api.proAnalysis(refresh: true);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _remaking = false);
    }
  }

  /// 章の会話・過去問から戻ったら、数字だけ取り直す（その日のプランはもうあるので作り直さない）
  Future<void> _then(Future<void> f) async {
    await f;
    if (mounted) _load(quiet: true);
  }

  String _chapterLabel(String chapterId) => switch (AppScope.read(context).chapter(chapterId)) { final c? => '第${c.order}章', null => chapterId };

  Future<void> _toPro() async {
    final state = AppScope.read(context);
    await ProScreen.show(context, reason: 'analysis');
    // Pro になったら、そのままプランを作って見せる
    if (mounted && state.me?['pro'] == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('苦手分析と学習プラン')),
      body: d == null
          ? Center(child: _error != null ? LoadError(error: _error!, onRetry: _load) : const _Making())
          : RefreshIndicator(onRefresh: () => _load(quiet: true), child: _body(d)),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final pro = d['pro'] == true;
    final a = (d['analysis'] as Map?)?.cast<String, dynamic>() ?? const {};
    final plan = (d['plan'] as Map?)?.cast<String, dynamic>();
    final subjects = ((a['subjects'] as List?) ?? const []).cast<Map>();
    final weak = ((a['weak'] as List?) ?? const []).cast<Map>();
    final untouched = ((a['untouched'] as List?) ?? const []).cast<Map>();
    final left = (d['plansLeft'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Summary(a: a),
              const SizedBox(height: 16),
              if (pro) ...[
                if (plan != null) _PlanCard(plan: plan, onLearn: (c, p) => _then(openChapter(context, c, pointId: p)), onKakomon: (c, p, t) => _then(openKakomon(context, set: c, label: _chapterLabel(c), point: p, pointTitle: t))),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _remaking || left <= 0 ? null : _remake,
                  icon: _remaking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 20),
                  label: Text(_remaking ? 'プランを作っています…' : left > 0 ? 'プランを作り直す（あと $left 回）' : '今日はもう作り直せません'),
                ),
                const SizedBox(height: 28),
              ],
              const _Heading('科目ごとの正答率'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(children: [for (final s in subjects) _SubjectRow(s: s.cast<String, dynamic>())]),
                ),
              ),
              const SizedBox(height: 6),
              Text('答えた問題 ÷ その科目の過去問の数。正答率は答えたすべての回の割合です。', style: Theme.of(context).textTheme.bodySmall),
              if (!pro) ...[
                const SizedBox(height: 20),
                _Locked(onPro: _toPro),
              ] else ...[
                const SizedBox(height: 28),
                const _Heading('苦手な論点'),
                if (weak.isEmpty)
                  Text('まだありません（2回以上答えて正答率が7割に届かない論点を出します）。', style: Theme.of(context).textTheme.bodySmall)
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (final (i, w) in weak.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _WeakRow(w: w.cast<String, dynamic>(), onTap: () => _then(openChapter(context, w['chapterId'] as String, pointId: w['pointId'] as String?))),
                      ],
                    ]),
                  ),
                if (untouched.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _Heading('まだ手をつけていない章'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final u in untouched)
                        ActionChip(
                          label: Text(u['chapter'] as String? ?? ''),
                          backgroundColor: Palette.paper,
                          side: const BorderSide(color: Palette.lineStrong),
                          onPressed: () => _then(openChapter(context, u['chapterId'] as String)),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// プランを作っているあいだ（その日の最初は AI が書くので少し待つ）
class _Making extends StatelessWidget {
  const _Making();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('答えた記録を集めて、今週の学習プランを作っています。\n10秒ほどお待ちください。', textAlign: TextAlign.center, style: TextStyle(color: Palette.inkSoft)),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
  );
}

String _pct(Object? v) => v is num ? '${(v * 100).round()}%' : '—';

/// 答えた問題・全体の正答率・試験まで
class _Summary extends StatelessWidget {
  const _Summary({required this.a});
  final Map<String, dynamic> a;

  @override
  Widget build(BuildContext context) {
    final days = (a['daysToExam'] as num?)?.toInt();
    Widget fig(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink)),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          fig('答えた問題', '${a['answered'] ?? 0}問'),
          fig('正答率', _pct(a['accuracy'])),
          fig('試験まで', days == null || days < 0 ? '—' : 'あと$days日'),
        ]),
      ),
    );
  }
}

/// AI のプラン: 方針 → まずやること（論点ごとに「先生と学ぶ」「過去問を解く」）→ 7日の目安
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onLearn, required this.onKakomon});
  final Map<String, dynamic> plan;
  final void Function(String chapterId, String pointId) onLearn;
  final void Function(String chapterId, String pointId, String title) onKakomon;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final focus = ((plan['focus'] as List?) ?? const []).cast<Map>();
    final week = ((plan['week'] as List?) ?? const []).map((x) => '$x').toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: Palette.aiSoft, border: Border.all(color: Palette.ai.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome, size: 18, color: Palette.ai),
            SizedBox(width: 6),
            Text('今週の学習プラン', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.ai)),
          ]),
          const SizedBox(height: 6),
          Text(plan['headline'] as String? ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.6, color: Palette.ink)),
          if (focus.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('まずやること', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
            for (final f in focus) ...[
              const SizedBox(height: 8),
              _FocusItem(
                f: f.cast<String, dynamic>(),
                chapter: switch (state.chapter(f['chapterId'] as String? ?? '')) { final c? => '第${c.order}章 ${c.short.isNotEmpty ? c.short : c.title}', null => '' },
                onLearn: () => onLearn(f['chapterId'] as String, f['pointId'] as String),
                onKakomon: () => onKakomon(f['chapterId'] as String, f['pointId'] as String, f['title'] as String? ?? ''),
              ),
            ],
          ],
          if (week.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('7日の目安', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
            const SizedBox(height: 4),
            for (final w in week)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(w, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink)),
              ),
          ],
          const SizedBox(height: 8),
          const Text('プランは AI が答えた記録から作った目安です。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

class _FocusItem extends StatelessWidget {
  const _FocusItem({required this.f, required this.chapter, required this.onLearn, required this.onKakomon});
  final Map<String, dynamic> f;
  final String chapter;
  final VoidCallback onLearn;
  final VoidCallback onKakomon;

  @override
  Widget build(BuildContext context) {
    final kakomon = f['action'] == 'kakomon';
    const small = Size(44, 40);
    const text = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    final learnBtn = kakomon
        ? OutlinedButton(onPressed: onLearn, style: OutlinedButton.styleFrom(minimumSize: small, textStyle: text), child: const Text('先生と学ぶ'))
        : FilledButton(onPressed: onLearn, style: FilledButton.styleFrom(minimumSize: small, textStyle: text), child: const Text('先生と学ぶ'));
    final kakomonBtn = kakomon
        ? FilledButton(onPressed: onKakomon, style: FilledButton.styleFrom(minimumSize: small, textStyle: text), child: const Text('過去問を解く'))
        : OutlinedButton(onPressed: onKakomon, style: OutlinedButton.styleFrom(minimumSize: small, textStyle: text), child: const Text('過去問を解く'));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chapter.isNotEmpty) Text(chapter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
          Text(f['title'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
          if ((f['reason'] as String? ?? '').isNotEmpty) Text(f['reason'] as String, style: const TextStyle(fontSize: 13, height: 1.5, color: Palette.inkSoft)),
          const SizedBox(height: 8),
          // おすすめ（action）のほうを塗りのボタンに
          Row(children: [Expanded(child: kakomon ? kakomonBtn : learnBtn), const SizedBox(width: 8), Expanded(child: kakomon ? learnBtn : kakomonBtn)]),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.s});
  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final acc = s['accuracy'];
    final answered = (s['answered'] as num?)?.toInt() ?? 0;
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final color = acc is num && acc < 0.6 ? Palette.danger : acc is num && acc < 0.7 ? Palette.warning : Palette.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(s['label'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink))),
            Text(_pct(acc), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: acc is num ? color : Palette.inkFaint)),
          ]),
          const SizedBox(height: 4),
          ProgressBar(value: acc is num ? acc.toDouble() : 0, color: color, height: 8),
          const SizedBox(height: 2),
          Text('答えた問題 $answered/$total', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

class _WeakRow extends StatelessWidget {
  const _WeakRow({required this.w, required this.onTap});
  final Map<String, dynamic> w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w['chapter'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Palette.primary, fontWeight: FontWeight.w700)),
            Text(w['title'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
            Text('${w['attempts'] ?? 0}回答えた・過去問 ${w['kakomon'] ?? 0}問', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          ]),
        ),
        Text(_pct(w['accuracy']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.danger)),
        const Icon(Icons.chevron_right, color: Palette.inkFaint),
      ]),
    ),
  );
}

/// Pro でない人に: Pro で増えるもの
class _Locked extends StatelessWidget {
  const _Locked({required this.onPro});
  final VoidCallback onPro;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.highlight, width: 1.5), borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [
          ProBadge(),
          SizedBox(width: 8),
          Expanded(child: Text('Pro で見られるもの', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink))),
        ]),
        const SizedBox(height: 8),
        for (final t in const ['正答率の低い論点（2回以上答えたもの）と、その論点の過去問の数', 'AI が記録から作る今週の学習プラン（まずやること・7日の目安）', 'まだ手をつけていない章', '模擬試験（本番の比率で50問・AI の講評つき）'])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('・$t', style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink)),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onPro, child: const Text('Pro について見る')),
      ],
    ),
  );
}
