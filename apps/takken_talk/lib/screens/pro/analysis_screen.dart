import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/readable.dart';
import '../common/parts.dart';
import '../pro_screen.dart';
import 'analysis_logic.dart';
import 'plan_tasks.dart';

/// 苦手分析と学習プラン（GET /pro/analysis → { pro, report, plan, plansLeft }。形はサイトの src/lib/server/analysis.ts の Report と
/// pro.ts の Plan、考え方は docs/pro-analysis.md）。Pro の目玉なので、文の壁にせず「数字を大きく・カードで区切る」。
/// 並び: 予測点 → AI の学習プラン → 優先したい論点 → 章ごとの出来 → まちがい方の癖 → 学習量とペース → まだ解いていない頻出論点。
/// Pro でない人（pro: false）: 予測点と科目だけ見せ、Pro で何が見られるかを伝えて Pro の案内へ。
/// 広告は出さない（Pro の機能の画面なので）。
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, this.scrollToToday = false});

  /// 開いたら「7日の予定」の今日まで動かす（ホームの「今日の予定」から開いたとき）
  final bool scrollToToday;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  /// プランを作り直しているあいだ（AI が書くので 10〜20 秒）
  bool _remaking = false;
  final _todayKey = GlobalKey();
  bool _scrolled = false;

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
      if (widget.scrollToToday && !_scrolled) {
        _scrolled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _todayKey.currentContext;
          if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
        });
      }
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  /// 予定のタスクの済みを付け外しする。先に画面を変え、失敗したら戻す
  Future<void> _toggle(String taskId, bool done) async {
    final d = _data;
    final plan = (d?['plan'] as Map?)?.cast<String, dynamic>();
    if (d == null || plan == null) return;
    setState(() => _data = {...d, 'plan': checkedPlan(plan, taskId, done)});
    try {
      final r = await AppScope.read(context).api.checkPlanTask(planAt: plan['createdAt'] as num, taskId: taskId, done: done);
      final fresh = r['plan'];
      if (mounted && fresh is Map && _data != null) setState(() => _data = {..._data!, 'plan': fresh.cast<String, dynamic>()});
    } catch (e) {
      if (!mounted) return;
      setState(() => _data = {...?_data, 'plan': plan});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
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

  void _learn(String chapterId, String? pointId) => _then(openChapter(context, chapterId, pointId: pointId));

  void _kakomon(String chapterId, {String? pointId, String? title}) {
    final c = AppScope.read(context).chapter(chapterId);
    _then(openKakomon(context, set: chapterId, label: c == null ? chapterId : '第${c.order}章', point: pointId, pointTitle: title ?? (c == null ? null : (c.short.isNotEmpty ? c.short : c.title))));
  }

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
    final r = (d['report'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final plan = (d['plan'] as Map?)?.cast<String, dynamic>();
    final totals = (r['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final empty = ((totals['answered'] as num?) ?? 0) == 0;
    final priorities = _maps(r['priorities']);
    final chapters = _maps(r['chapters']);
    final untouched = _maps(r['frequentUntouched']);
    final habits = (r['habits'] as Map?)?.cast<String, dynamic>();
    final pace = (r['pace'] as Map?)?.cast<String, dynamic>();
    final sections = <Widget>[
      if (empty) _EmptyGuide(onStart: () => _kakomon(AppScope.read(context).chapters.firstOrNull?.id ?? 'ch01')),
      _ForecastCard(r: r),
      if (!pro)
        _Locked(onPro: _toPro)
      else ...[
        _PlanCard(plan: plan, left: (d['plansLeft'] as num?)?.toInt() ?? 0, remaking: _remaking, onRemake: _remake, onLearn: _learn, onKakomon: (c, p, t) => _kakomon(c, pointId: p, title: t), onToggle: _toggle, onStart: (t) => _then(startTask(context, t)), todayKey: _todayKey),
        if (priorities.isNotEmpty)
          _Section(
            title: '優先したい論点',
            sub: 'よく出るのに正答率が低い論点（3回以上答えたもの）。上から順に。',
            child: Column(children: [
              for (final p in priorities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PriorityCard(p: p, onLearn: () => _learn(p['chapterId'] as String, p['pointId'] as String?), onKakomon: () => _kakomon(p['chapterId'] as String, pointId: p['pointId'] as String?, title: p['title'] as String?)),
                ),
            ]),
          ),
        if (chapters.isNotEmpty) _Section(title: '章ごとの出来', sub: '押すとその章の過去問へ。', child: _ChapterGrid(chapters: chapters, onTap: (c) => _kakomon(c))),
        if (habits != null && !empty) _Section(title: 'まちがい方の癖', child: _Habits(h: habits)),
        if (pace != null) _Section(title: '学習量とペース', child: _Pace(p: pace, daysToExam: (r['daysToExam'] as num?)?.toInt())),
        if (untouched.isNotEmpty)
          _Section(
            title: 'まだ解いていない頻出論点',
            sub: '本試験13回のうち7回以上出た論点で、まだ1問も解いていないもの。',
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final (i, u) in untouched.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _UntouchedRow(u: u, onTap: () => _kakomon(u['chapterId'] as String, pointId: u['pointId'] as String?, title: u['title'] as String?)),
                ],
              ]),
            ),
          ),
      ],
    ];
    return ListView(
      key: const ValueKey('analysis_list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, s) in sections.indexed) ...[if (i > 0) const SizedBox(height: 24), s],
            ],
          ),
        ),
      ],
    );
  }
}

List<Map<String, dynamic>> _maps(Object? v) => ((v as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()).toList();

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
        Text('答えた記録を集めて、AI が今週の学習プランを作っています。\n10〜20秒ほどお待ちください。', textAlign: TextAlign.center, style: TextStyle(color: Palette.inkSoft)),
      ],
    ),
  );
}

/// 見出しと、その下のカード
class _Section extends StatelessWidget {
  const _Section({required this.title, this.sub, required this.child});
  final String title;
  final String? sub;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
      if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      child,
    ],
  );
}

/// 小さな印（「説明はまだ」「13回中 9回」「簡易版」）
class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color = Palette.inkSoft, this.bg = Palette.fill});
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );
}

/// 「先生と学ぶ」「過去問を解く」。おすすめ（action）のほうを塗りにする
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.action, required this.onLearn, required this.onKakomon});
  final String? action;
  final VoidCallback onLearn;
  final VoidCallback onKakomon;

  @override
  Widget build(BuildContext context) {
    final kakomon = action == 'kakomon';
    const small = Size(44, 40);
    const text = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    Widget btn(String label, bool main, VoidCallback onTap) => main
        ? FilledButton(onPressed: onTap, style: FilledButton.styleFrom(minimumSize: small, textStyle: text, padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(label))
        : OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(minimumSize: small, textStyle: text, padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(label));
    final learn = btn('先生と学ぶ', !kakomon, onLearn);
    final solve = btn('過去問を解く', kakomon, onKakomon);
    return Row(children: [Expanded(child: kakomon ? solve : learn), const SizedBox(width: 8), Expanded(child: kakomon ? learn : solve)]);
  }
}

/// まだ1問も答えていないとき
class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Palette.primarySoft, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('過去問を解くと、ここに分析が出ます', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.primaryStrong)),
        const SizedBox(height: 4),
        const Text('答えた記録から、予測点・苦手な論点・まちがい方の癖を出します。まずは第1章から10問ほど解いてみましょう。', style: TextStyle(fontSize: 14, height: 1.6, color: Palette.ink)),
        const SizedBox(height: 10),
        FilledButton(onPressed: onStart, child: const Text('第1章の過去問を解く')),
      ],
    ),
  );
}

/// 予測点: 大きな数字・幅・0〜50点の棒（合格点の目安と目標の印）・科目ごと
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final f = (r['forecast'] as Map?)?.cast<String, dynamic>() ?? const {};
    final score = (f['score'] as num?)?.toInt() ?? 0;
    final low = (f['low'] as num?)?.toInt() ?? score;
    final high = (f['high'] as num?)?.toInt() ?? score;
    final passLine = (f['passLine'] as num?)?.toInt() ?? 36;
    final target = (f['target'] as num?)?.toInt() ?? 39;
    final bySubject = _maps(f['bySubject']);
    final mock = (r['lastMock'] as Map?)?.cast<String, dynamic>();
    final good = score >= passLine;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('いまの予測点（本試験50問）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('予測 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
                Text('$score', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, height: 1.15, color: good ? Palette.success : Palette.primary)),
                const Text('点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink)),
                const SizedBox(width: 10),
                Flexible(child: Text('$low〜$high点（目安）', style: const TextStyle(fontSize: 14, color: Palette.inkSoft))),
              ],
            ),
            Text(forecastStatus(score: score, passLine: passLine, target: target), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: good ? Palette.success : Palette.warning)),
            const SizedBox(height: 10),
            _ScoreBar(score: score, low: low, high: high, passLine: passLine, target: target),
            const Divider(height: 28),
            for (final s in bySubject) _SubjectForecast(s: s),
            const SizedBox(height: 6),
            Text('○×の正答率と、解いた割合から出した目安です。', style: Theme.of(context).textTheme.bodySmall),
            if (mock != null) ...[
              const SizedBox(height: 4),
              Text('直近の模擬試験 ${mock['score']}/${mock['total']}点', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 0〜50点の棒。幅（low〜high）を薄く、予測点を濃い印、合格点の目安（下に文字）と目標（上に文字）を縦線で
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, required this.low, required this.high, required this.passLine, required this.target});
  final int score;
  final int low;
  final int high;
  final int passLine;
  final int target;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final w = c.maxWidth;
    double x(num v) => scorePos(v) * w;
    const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.inkSoft);
    Widget tick(num v, Color color) => Positioned(left: x(v) - 1, top: 14, child: Container(width: 2, height: 22, color: color));
    // 文字は棒の端からはみ出さないように寄せる
    double lx(num v, double labelW) => (x(v) - labelW / 2).clamp(0.0, w - labelW);
    return SizedBox(
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: lx(target, 60), top: 0, width: 60, child: Text('目標 $target', textAlign: TextAlign.center, style: label)),
          Positioned(left: 0, right: 0, top: 18, child: Container(height: 14, decoration: BoxDecoration(color: Palette.fillStrong, borderRadius: BorderRadius.circular(7)))),
          Positioned(left: x(low), width: (x(high) - x(low)).clamp(2.0, w), top: 18, child: Container(height: 14, decoration: BoxDecoration(color: Palette.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(7)))),
          tick(passLine, Palette.warning),
          tick(target, Palette.success),
          Positioned(left: x(score) - 9, top: 16, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Palette.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)))),
          Positioned(left: lx(passLine, 80), top: 38, width: 80, child: Text('合格点 $passLine', textAlign: TextAlign.center, style: label.copyWith(color: Palette.warning))),
          const Positioned(left: 0, top: 50, child: Text('0', style: TextStyle(fontSize: 11, color: Palette.inkFaint))),
          const Positioned(right: 0, top: 50, child: Text('50', style: TextStyle(fontSize: 11, color: Palette.inkFaint))),
        ],
      ),
    );
  });
}

/// 科目ごとの予測点と目標（目標との差は赤）
class _SubjectForecast extends StatelessWidget {
  const _SubjectForecast({required this.s});
  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final expected = (s['expected'] as num?) ?? 0;
    final target = (s['target'] as num?) ?? 0;
    final n = (s['examQuestions'] as num?) ?? 1;
    final gap = (s['gap'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('${s['label']}（${n.toInt()}問）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink))),
            Text.rich(TextSpan(children: [
              const TextSpan(text: '予測 ', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
              TextSpan(text: pts(expected), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink)),
              TextSpan(text: ' / 目標 ${pts(target)}', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
            ])),
            SizedBox(
              width: 64,
              child: Text(gap > 0 ? 'あと${pts(gap)}' : '到達', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gap > 0 ? Palette.danger : Palette.success)),
            ),
          ]),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, c) => Stack(children: [
            ProgressBar(value: expected / n, height: 8, color: gap > 0 ? Palette.primary : Palette.success),
            Positioned(left: (scorePos(target, max: n) * c.maxWidth - 1).clamp(0.0, c.maxWidth - 2), top: 0, bottom: 0, child: Container(width: 2, color: Palette.ink)),
          ])),
        ],
      ),
    );
  }
}

/// Pro でない人に: Pro で見られるもの
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
        for (final t in const [
          'AI の学習プラン（読み取れること・先にやること・7日の予定）',
          '優先したい論点（よく出るのに正答率が低い論点と、まちがえた問題）',
          '章ごとの出来（11章の正答率と解いた割合）',
          'まちがい方の癖（誤りの文を正しいと思いがち・数字に弱い・忘れ）',
          '学習量とペース（直近14日と、一通り解くのに要る1日の数）',
          'まだ解いていない頻出論点',
          '模擬試験（本番の比率で50問・AI の講評つき）',
        ])
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

/// AI の学習プラン: 方針 → 読み取れること → 先にやること → 7日の予定 → 作り直す
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.left, required this.remaking, required this.onRemake, required this.onLearn, required this.onKakomon, required this.onToggle, required this.onStart, this.todayKey});
  final Map<String, dynamic>? plan;
  final void Function(String taskId, bool done) onToggle;
  final void Function(Map<String, dynamic> task) onStart;

  /// 今日の見出し（ホームから開いたとき、そこまで動かす）
  final Key? todayKey;
  final int left;
  final bool remaking;
  final VoidCallback onRemake;
  final void Function(String chapterId, String? pointId) onLearn;
  final void Function(String chapterId, String? pointId, String? title) onKakomon;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final findings = ((p?['findings'] as List?) ?? const []).map((x) => '$x').toList();
    final focus = _maps(p?['focus']);
    final week = _maps(p?['week']);
    const h = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: Palette.aiSoft, border: Border.all(color: Palette.ai.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 18, color: Palette.ai),
            const SizedBox(width: 6),
            const Expanded(child: Text('AI の学習プラン', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ai))),
            if (p != null && p['ai'] == false) const _Tag('簡易版', color: Palette.ai, bg: Colors.white),
          ]),
          if (p == null) ...[
            const SizedBox(height: 6),
            const Text('プランはまだありません。', style: TextStyle(fontSize: 14, color: Palette.inkSoft)),
          ] else ...[
            const SizedBox(height: 6),
            Text(p['headline'] as String? ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.6, color: Palette.ink)),
            if (findings.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('読み取れること', style: h),
              for (final f in findings)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('・', style: TextStyle(fontSize: 14, height: 1.6)),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink))),
                  ]),
                ),
            ],
            if (focus.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('先にやること', style: h),
              for (final f in focus) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if ((f['chapter'] as String? ?? '').isNotEmpty) Text(f['chapter'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
                    Text('「${f['title'] ?? ''}」', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
                    if ((f['reason'] as String? ?? '').isNotEmpty) Text(f['reason'] as String, style: const TextStyle(fontSize: 13, height: 1.5, color: Palette.inkSoft)),
                    const SizedBox(height: 8),
                    _ActionButtons(
                      action: f['action'] as String?,
                      onLearn: () => onLearn(f['chapterId'] as String, f['pointId'] as String?),
                      onKakomon: () => onKakomon(f['chapterId'] as String, f['pointId'] as String?, f['title'] as String?),
                    ),
                  ]),
                ),
              ],
            ],
            if (week.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('7日の予定', style: h),
              const Text('押すとその練習が始まります。その日に解けば自動で済みに。丸を押して自分で付け外しもできます。', style: TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
              const SizedBox(height: 6),
              _WeekList(week: week, todayKey: todayKey, onToggle: onToggle, onStart: onStart),
            ],
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: remaking || left <= 0 ? null : onRemake,
            style: OutlinedButton.styleFrom(backgroundColor: Palette.paper),
            icon: remaking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 20),
            label: Text(remaking ? 'プランを作っています（10〜20秒）' : left > 0 ? 'プランを作り直す（あと $left 回）' : '今日はもう作り直せません'),
          ),
          const SizedBox(height: 4),
          const Text('プランは AI が答えた記録の数字から作った目安です。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

String _ox(Object? a) => a == null ? '未回答' : (a == true ? '○' : '×');

/// 優先したい論点の1つ: 名前・章と科目・何回出たか・正答率の棒・説明はまだ・まちがえた問題（開く）・次にやること
class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.p, required this.onLearn, required this.onKakomon});
  final Map<String, dynamic> p;
  final VoidCallback onLearn;
  final VoidCallback onKakomon;

  @override
  Widget build(BuildContext context) {
    final acc = p['accuracy'] as num?;
    final missed = _maps(p['missed']);
    final color = acc != null && acc < 0.5 ? Palette.danger : Palette.warning;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${p['chapter'] ?? ''}・${p['subject'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
            Text(p['title'] as String? ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _Tag('本試験13回中 ${p['years'] ?? 0}回', color: Palette.primaryStrong, bg: Palette.primarySoft),
              if (p['taught'] != true) const _Tag('説明はまだ', color: Palette.warning, bg: Palette.warningSoft),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('正答率', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
              const SizedBox(width: 8),
              Expanded(child: ProgressBar(value: acc?.toDouble() ?? 0, color: color, height: 8)),
              const SizedBox(width: 8),
              Text(pct(acc), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            ]),
            Text('${p['attempts'] ?? 0}回答えた・この論点の過去問 ${p['kakomon'] ?? 0}問', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
            if (missed.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('まちがえた問題 ${missed.length}問', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.danger)),
                  children: [for (final m in missed) _MissedQuestion(m: m)],
                ),
              )
            else
              const SizedBox(height: 8),
            _ActionButtons(action: p['action'] as String?, onLearn: onLearn, onKakomon: onKakomon),
          ],
        ),
      ),
    );
  }
}

class _MissedQuestion extends StatelessWidget {
  const _MissedQuestion({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(6)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(m['statement'] as String? ?? '', style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink)),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'あなたの答え '),
          TextSpan(text: _ox(m['yourAnswer']), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.danger)),
          const TextSpan(text: '・正しい答え '),
          TextSpan(text: _ox(m['correctAnswer']), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.success)),
        ]), style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
        if ((m['origin'] as String? ?? '').isNotEmpty) Text('${m['origin']} の論点（文は作り直し）', style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
      ],
    ),
  );
}

/// 章の状態の色と名前（サイトの status: untouched / weak 6割未満 / fair / good 8割以上）
(Color, Color, String) _statusStyle(String? s) => switch (s) {
  'weak' => (Palette.danger, Palette.dangerSoft, '苦手'),
  'fair' => (Palette.warning, Palette.warningSoft, 'まずまず'),
  'good' => (Palette.success, Palette.successSoft, '得意'),
  _ => (Palette.inkFaint, Palette.fill, '手つかず'),
};

/// 11章を2列のタイルで。色が状態、大きな数字が正答率、下の棒が解いた割合
class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({required this.chapters, required this.onTap});
  final List<Map<String, dynamic>> chapters;
  final void Function(String chapterId) onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(spacing: 10, children: [
        for (final s in ['good', 'fair', 'weak', 'untouched'])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusStyle(s).$1, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(_statusStyle(s).$3, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          ]),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final ch in chapters) SizedBox(width: w, child: _ChapterTile(c: ch, onTap: () => onTap(ch['chapterId'] as String)))]);
      }),
    ],
  );
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.c, required this.onTap});
  final Map<String, dynamic> c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = _statusStyle(c['status'] as String?);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: fg, width: 4)), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('第${c['order']}章 ${c['short'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.ink)),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(pct(c['accuracy']), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              ]),
              ProgressBar(value: ((c['coverage'] as num?) ?? 0).toDouble(), color: fg, height: 4),
              const SizedBox(height: 2),
              Text('解いた ${c['answered'] ?? 0}/${c['total'] ?? 0}問', style: const TextStyle(fontSize: 11, color: Palette.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// まちがい方の癖。数字の小さなタイル（データが無いものは出さない）と、目立つ差の読み方
class _Habits extends StatelessWidget {
  const _Habits({required this.h});
  final Map<String, dynamic> h;

  @override
  Widget build(BuildContext context) {
    final tf = (h['trustsFalse'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dt = (h['doubtsTrue'] as Map?)?.cast<String, dynamic>() ?? const {};
    final n = (h['numbers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final t = (h['trend'] as Map?)?.cast<String, dynamic>() ?? const {};
    final forgotten = (h['forgotten'] as num?)?.toInt() ?? 0;
    final notes = habitNotes(h);
    final tiles = <Widget>[
      if ((tf['asked'] as num? ?? 0) > 0 || (dt['asked'] as num? ?? 0) > 0)
        _PairTile(
          title: '○と×の取り違え',
          a: ('誤りの文を正しいと思った', pct(tf['rate']), '${tf['wrong'] ?? 0}/${tf['asked'] ?? 0}'),
          b: ('正しい文を誤りと思った', pct(dt['rate']), '${dt['wrong'] ?? 0}/${dt['asked'] ?? 0}'),
          note: 'まちがえた割合',
        ),
      if ((n['answered'] as num? ?? 0) > 0)
        _PairTile(title: '数字の入った問題', a: ('数字の入った問題', pct(n['accuracy']), '${n['answered']}回'), b: ('それ以外', pct(n['othersAccuracy']), null), note: '正答率'),
      if ((t['recentCount'] as num? ?? 0) > 0 || (t['beforeCount'] as num? ?? 0) > 0)
        _PairTile(title: '正答率の変化', a: ('直近7日', pct(t['recent']), '${t['recentCount'] ?? 0}回'), b: ('それより前', pct(t['before']), '${t['beforeCount'] ?? 0}回'), note: '正答率'),
      _OneTile(label: '一度できたのに忘れた', value: '$forgotten問', bad: forgotten >= 5),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: Palette.highlightSoft, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.lightbulb_outline, size: 16, color: Palette.warning)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink))),
                  ]),
                ),
            ]),
          ),
        for (final (i, tile) in tiles.indexed) ...[if (i > 0) const SizedBox(height: 8), tile],
      ],
    );
  }
}

/// 2つの数字を並べて比べるタイル
class _PairTile extends StatelessWidget {
  const _PairTile({required this.title, required this.a, required this.b, required this.note});
  final String title;
  final (String, String, String?) a;
  final (String, String, String?) b;
  final String note;

  @override
  Widget build(BuildContext context) {
    Widget side((String, String, String?) x) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(x.$1, style: const TextStyle(fontSize: 12, height: 1.4, color: Palette.inkSoft)),
        Text.rich(TextSpan(children: [
          TextSpan(text: x.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Palette.ink)),
          if (x.$3 != null) TextSpan(text: '（${x.$3}）', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
        ])),
      ]),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$title（$note）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side(a), Container(width: 1, height: 44, color: Palette.line, margin: const EdgeInsets.symmetric(horizontal: 10)), side(b)]),
        ]),
      ),
    );
  }
}

class _OneTile extends StatelessWidget {
  const _OneTile({required this.label, required this.value, this.bad = false});
  final String label;
  final String value;
  final bool bad;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary))),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: bad ? Palette.danger : Palette.ink)),
      ]),
    ),
  );
}

/// 学習量とペース: 直近14日の棒（右端が今日）と、日数・平均・連続、残りの過去問と1日の目安
class _Pace extends StatelessWidget {
  const _Pace({required this.p, required this.daysToExam});
  final Map<String, dynamic> p;
  final int? daysToExam;

  @override
  Widget build(BuildContext context) {
    final days = _maps(p['days']);
    final top = days.fold<int>(0, (a, d) => ((d['answered'] as num?)?.toInt() ?? 0) > a ? (d['answered'] as num).toInt() : a);
    final remaining = (p['remaining'] as num?)?.toInt() ?? 0;
    final needed = (p['neededPerDay'] as num?)?.toInt();
    final until = daysToExam != null && daysToExam! - 14 >= 7 ? '試験2週間前に' : '試験日までに';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, d) in days.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (((d['answered'] as num?) ?? 0) > 0) Text('${d['answered']}', style: const TextStyle(fontSize: 9, color: Palette.inkSoft)),
                            Container(
                              height: top == 0 ? 2 : 2 + 70 * (((d['answered'] as num?) ?? 0) / top),
                              decoration: BoxDecoration(color: i == days.length - 1 ? Palette.primary : Palette.primary.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(height: 3),
                            Text(i == days.length - 1 ? '今日' : (i % 2 == 1 ? '${int.tryParse((d['day'] as String? ?? '').split('-').last) ?? ''}' : ''), style: const TextStyle(fontSize: 9, color: Palette.inkFaint)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('直近14日で ${p['activeDays14'] ?? 0}日・1日平均 ${p['avgPerDay14'] ?? 0}問・連続 ${p['streak'] ?? 0}日', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
            const SizedBox(height: 4),
            Text(
              remaining == 0 ? '過去問はすべて一度は解きました。' : 'まだ解いていない過去問 $remaining問${needed == null ? '' : ' → 1日 $needed問で$until一通り'}',
              style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _UntouchedRow extends StatelessWidget {
  const _UntouchedRow({required this.u, required this.onTap});
  final Map<String, dynamic> u;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['chapter'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary)),
            Text('「${u['title'] ?? ''}」', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
            Text('過去問 ${u['kakomon'] ?? 0}問', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          ]),
        ),
        _Tag('13回中 ${u['years'] ?? 0}回', color: Palette.primaryStrong, bg: Palette.primarySoft),
        const Icon(Icons.chevron_right, color: Palette.inkFaint),
      ]),
    ),
  );
}

/// 7日の予定。日ごとに見出し（「10/22（水）」・今日・できた数）と、タスクの行。今日は開き、過ぎた日は閉じておく
class _WeekList extends StatefulWidget {
  const _WeekList({required this.week, required this.onToggle, required this.onStart, this.todayKey});
  final List<Map<String, dynamic>> week;
  final void Function(String taskId, bool done) onToggle;
  final void Function(Map<String, dynamic> task) onStart;
  final Key? todayKey;

  @override
  State<_WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<_WeekList> {
  /// 開け閉めを自分で変えた日（index → 開いているか）。変えていない日は、過ぎた日だけ閉じる
  final Map<int, bool> _open = {};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, d) in widget.week.indexed) ...[
        if (i > 0) const SizedBox(height: 6),
        _day(i, d),
      ],
    ],
  );

  Widget _day(int i, Map<String, dynamic> d) {
    final tasks = taskList(d);
    final today = d['isToday'] == true;
    final past = d['isPast'] == true;
    final doneCount = (d['doneCount'] as num?)?.toInt() ?? tasks.where((t) => t['done'] == true).length;
    final all = tasks.isNotEmpty && doneCount == tasks.length;
    final open = _open[i] ?? !past;
    final date = d['date'] as String?;
    return Container(
      key: today ? widget.todayKey : null,
      decoration: BoxDecoration(
        color: past ? Palette.paper.withValues(alpha: 0.6) : Palette.paper,
        border: Border.all(color: today ? Palette.ai : Palette.line, width: today ? 1.5 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open[i] = !open),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(children: [
                Text(date == null ? '${d['day'] ?? ''}' : dateLabel(date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: past ? Palette.inkSoft : Palette.ink)),
                const SizedBox(width: 6),
                if (today) const _Tag('今日', color: Colors.white, bg: Palette.ai),
                const Spacer(),
                Text(all ? 'ぜんぶできた' : '$doneCount/${tasks.length} できた', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: all ? Palette.success : Palette.inkSoft)),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20, color: Palette.inkFaint),
              ]),
            ),
          ),
          if (open) ...[
            for (final t in tasks)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: PlanTaskRow(task: t, dim: past, onToggle: (v) => widget.onToggle(t['id'] as String, v), onStart: () => widget.onStart(t)),
              ),
            if (today && all) const Padding(padding: EdgeInsets.fromLTRB(8, 2, 8, 8), child: AllDoneBanner()),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
