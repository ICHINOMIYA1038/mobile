import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../ads/ad_banner.dart';
import '../main.dart';
import '../models/core.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/readable.dart';
import 'common/parts.dart';
import 'map_screen.dart';
import 'pro/analysis_screen.dart';
import 'pro/mock_screen.dart';
import 'pro/plan_tasks.dart';
import 'pro_screen.dart';

/// 「学ぶ」タブ（サイトの /takken と同じ並び: いまの状況 → 続きから → カリキュラム）。
/// データは AppState.home（タブを開くたびに main.dart が取り直す）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final home = state.home ?? const {};
    final progress = (home['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byId = {for (final p in (progress['chapters'] as List? ?? const [])) (p as Map)['chapterId'] as String: p.cast<String, dynamic>()};
    final chapters = state.chapters;
    return Scaffold(
      // Pro でない人にだけ、一覧の下にバナー（下のタブの上）
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: const Text('pAIrOf 宅建', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: () => _openMap(context),
            icon: const Icon(Icons.map_outlined),
            label: const Text('学習の地図'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Readable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Status(home: home, progress: progress, state: state),
                  const SizedBox(height: 12),
                  _Next(home: home, first: chapters.firstOrNull, state: state),
                  const SizedBox(height: 20),
                  // Pro の人には、学習プランの今日の予定（タスクを押せばその練習へ）
                  if (state.me?['pro'] == true) ...[
                    const _TodayCard(),
                    const SizedBox(height: 20),
                  ],
                  _ProTools(pro: state.me?['pro'] == true),
                  const SizedBox(height: 28),
                  const Text(
                    'カリキュラム',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink),
                  ),
                  const SizedBox(height: 4),
                  Text('本試験${home['examQuestions'] ?? 50}問のうち、配点の大きい科目から並べています。上から順に進めるのが最短です。', style: Theme.of(context).textTheme.bodySmall),
                  for (final s in state.subjects) ...[
                    const SizedBox(height: 20),
                    SubjectHeading(name: s.name, examQuestions: s.examQuestions),
                    if (s.summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 8),
                        child: Text(s.summary, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    for (final id in s.chapterIds)
                      if (state.chapter(id) case final c?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _ChapterTile(chapter: c, progress: byId[id], kakomon: ((home['kakomonByChapter'] as Map?)?[id] as num?)?.toInt() ?? 0),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 地図からも章を開けるので、戻ったら取り直す
  static void _openMap(BuildContext context) {
    final state = AppScope.read(context);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const MapScreen(),
            settings: const RouteSettings(name: 'map'),
          ),
        )
        .then((_) => state.refresh());
  }
}

/// 章の会話を開き、戻ったら進み具合・続きからを取り直す
void _open(BuildContext context, String chapterId) {
  final state = AppScope.read(context);
  openChapter(context, chapterId).then((_) => state.refresh());
}

/// 今日の予定（GET pro/today）。学習プランの7日の予定のうち今日のタスク。押せばその練習へ、丸で済み・未済み。
/// プランがまだ無い・7日を過ぎたときは、苦手分析の画面（開くとプランを作る）への入口だけ。
/// ホームが取り直される（AppState.home が新しくなる）たびに取り直す。タブを開いたとき・章や過去問から戻ったときに main.dart や各画面が refresh する。
class _TodayCard extends StatefulWidget {
  const _TodayCard();

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  Map<String, dynamic>? _today;
  bool _loaded = false;
  Object? _homeSeen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final home = AppScope.of(context).home;
    if (!identical(home, _homeSeen)) {
      _homeSeen = home;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.proToday();
      if (mounted) {
        setState(() {
          _today = (d['today'] as Map?)?.cast<String, dynamic>();
          _loaded = true;
        });
      }
    } catch (_) {
      // 読めなければ前のまま（ホームのほかの所は使える）
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggle(String taskId, bool done) async {
    final t = _today;
    if (t == null) return;
    setState(() => _today = checkedToday(t, taskId, done));
    try {
      await AppScope.read(context).api.checkPlanTask(planAt: t['planAt'] as num, taskId: taskId, done: done);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _today = t);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _start(Map<String, dynamic> task) async {
    final state = AppScope.read(context);
    await startTask(context, task);
    // 戻ったらホームごと取り直す（この予定も didChangeDependencies で取り直る）
    state.refresh();
  }

  void _analysis({bool toToday = false}) {
    final state = AppScope.read(context);
    AppInsights.logEvent('pro_tool_open', parameters: {'tool': 'analysis', 'pro': 1, 'from': 'today'});
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => AnalysisScreen(scrollToToday: toToday), settings: const RouteSettings(name: 'pro_analysis')))
        .then((_) => state.refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final t = _today;
    final tasks = taskList(t);
    if (t == null || t['expired'] == true || tasks.isEmpty) {
      final expired = t != null;
      return Material(
        color: Palette.aiSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: const ValueKey('today_cta'),
          onTap: _analysis,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: Palette.ai),
              const SizedBox(width: 10),
              Expanded(child: Text(expired ? '新しいプランを作る（前のプランは7日たちました）' : 'AI に今週の学習プランを作ってもらう', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink))),
              const Icon(Icons.chevron_right, color: Palette.ai),
            ]),
          ),
        ),
      );
    }
    final doneCount = (t['doneCount'] as num?)?.toInt() ?? tasks.where((x) => x['done'] == true).length;
    final streak = (t['streak'] as num?)?.toInt() ?? 0;
    final all = doneCount == tasks.length;
    return Container(
      key: const ValueKey('today_card'),
      decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.ai.withValues(alpha: 0.5), width: 1.5), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _analysis(toToday: true),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, size: 18, color: Palette.ai),
                  const SizedBox(width: 6),
                  Text('今日の予定${t['date'] is String ? '  ${dateLabel(t['date'] as String)}' : ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
                  const Spacer(),
                  if (streak >= 2) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: Palette.highlightSoft, borderRadius: BorderRadius.circular(999)),
                      child: Text('連続 $streak日', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.warning)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text('$doneCount/${tasks.length} できた', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: all ? Palette.success : Palette.inkSoft)),
                  const Icon(Icons.chevron_right, size: 20, color: Palette.inkFaint),
                ]),
                const SizedBox(height: 2),
                Text(t['headline'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          for (final task in tasks) PlanTaskRow(task: task, onToggle: (v) => _toggle(task['id'] as String, v), onStart: () => _start(task)),
          if (all) const Padding(padding: EdgeInsets.fromLTRB(4, 4, 4, 2), child: AllDoneBanner()),
        ],
      ),
    );
  }
}

/// Pro の学習ツール（苦手分析と学習プラン・模擬試験）。Pro でない人には「Pro」の印を付ける。
/// 苦手分析は Pro でなくても開ける（科目ごとの正答率だけ見せて、Pro で何が増えるかを伝える）。模擬試験は Pro の案内を開く。
class _ProTools extends StatelessWidget {
  const _ProTools({required this.pro});
  final bool pro;

  void _analysis(BuildContext context) {
    AppInsights.logEvent('pro_tool_open', parameters: {'tool': 'analysis', 'pro': pro ? 1 : 0});
    final state = AppScope.read(context);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AnalysisScreen(), settings: const RouteSettings(name: 'pro_analysis')))
        .then((_) => state.refresh());
  }

  void _mock(BuildContext context) {
    AppInsights.logEvent('pro_tool_open', parameters: {'tool': 'mock', 'pro': pro ? 1 : 0});
    if (!pro) {
      ProScreen.show(context, reason: 'mock');
      return;
    }
    final state = AppScope.read(context);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MockIntroScreen(), settings: const RouteSettings(name: 'pro_mock')))
        .then((_) => state.refresh());
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Pro の学習ツール', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _ToolRow(icon: Icons.insights, title: '苦手分析と学習プラン', sub: '科目・論点ごとの正答率と、AI が作る今週のプラン', locked: !pro, onTap: () => _analysis(context)),
            const Divider(height: 1),
            _ToolRow(icon: Icons.timer_outlined, title: '模擬試験（本番の比率で50問）', sub: '30分で過去問の○×を解いて、採点と AI の講評', locked: !pro, onTap: () => _mock(context)),
          ],
        ),
      ),
    ],
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.icon, required this.title, required this.sub, required this.locked, required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Icon(icon, color: Palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)),
                Text(sub, style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.inkSoft)),
              ],
            ),
          ),
          if (locked) ...[const SizedBox(width: 8), const ProBadge()],
          const Icon(Icons.chevron_right, color: Palette.inkFaint),
        ],
      ),
    ),
  );
}

/// 試験までの日数と、定着・説明済み・今日話せる回数
class _Status extends StatelessWidget {
  const _Status({required this.home, required this.progress, required this.state});
  final Map<String, dynamic> home;
  final Map<String, dynamic> progress;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final days = (home['daysToExam'] as num?)?.toInt();
    final hasDate = days != null && days >= 0;
    final left = (state.capToday - state.usedToday).clamp(0, state.capToday);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              hasDate
                  ? TextSpan(
                      children: [
                        const TextSpan(text: '試験まで '),
                        TextSpan(
                          text: 'あと$days日',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Palette.primary),
                        ),
                      ],
                    )
                  : const TextSpan(text: '試験日が未設定です'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
            Row(
              children: [
                if (hasDate) Text('${home['examDate']}', style: const TextStyle(fontSize: 14, color: Palette.inkSoft)),
                TextButton(
                  onPressed: () => Shell.select(context, 4),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(hasDate ? '試験日を変える' : '試験日を入れる', style: const TextStyle(fontSize: 14, decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Figure(label: '定着した問題', value: '${progress['mastered'] ?? 0}', of: '${progress['totalQuestions'] ?? 0}'),
                  _Figure(label: '説明を聞いた論点', value: '${progress['pointsTaught'] ?? 0}', of: '${progress['points'] ?? 0}'),
                  state.unlimited ? const _Figure(label: '今日話せる回数', value: '無制限') : _Figure(label: '今日話せる回数', value: '$left', of: '${state.capToday}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.of});
  final String label;
  final String value;
  final String? of;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.inkSoft, height: 1.4)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink),
              ),
              if (of != null)
                TextSpan(
                  text: '/$of',
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 前回の続きから（無ければ第1章から始める）
class _Next extends StatelessWidget {
  const _Next({required this.home, required this.first, required this.state});
  final Map<String, dynamic> home;
  final ChapterSummary? first;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final resume = (home['resume'] as Map?)?.cast<String, dynamic>();
    final small = Theme.of(context).textTheme.bodySmall;
    if (resume != null) {
      final topic = resume['topic'] as String?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('前回の続きから', style: small),
          const SizedBox(height: 6),
          _BigButton(title: '第${resume['order']}章 ${resume['title']}', sub: topic != null ? '（$topic）' : null, onTap: () => _open(context, resume['chapterId'] as String)),
        ],
      );
    }
    final c = first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${home['tagline'] ?? ''}。先生が論点を順に説明し、選択肢と○×で確かめながら進みます。', style: const TextStyle(fontSize: 15, height: 1.7, color: Palette.ink)),
        const SizedBox(height: 10),
        if (c != null) _BigButton(title: '第1章「${c.short.isNotEmpty ? c.short : c.title}」から始める', onTap: () => _open(context, c.id)),
        const SizedBox(height: 6),
        // App Store の決まり（3.1.1）でアプリの外の買い方や「無料」には触れない。回数の上限だけ伝える
        Text(state.unlimited ? '登録はいりません。' : '登録はいりません。1日${state.capToday}回まで話せます。', style: small),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.title, this.sub, required this.onTap});
  final String title;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Palette.primary,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            const Icon(Icons.forum, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
                  ),
                  if (sub != null) Text(sub!, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

/// 章の行。進み具合は「説明を聞いた論点」と「解いた問題」の2つ（棒は論点の説明）
class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.progress, this.kakomon = 0});
  final ChapterSummary chapter;
  final Map<String, dynamic>? progress;

  /// この章の過去問の数（0 なら入口を出さない）
  final int kakomon;

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    final p = progress;
    final taught = (p?['pointsTaught'] as num?)?.toInt() ?? 0;
    final points = (p?['points'] as num?)?.toInt() ?? c.pointCount;
    final seen = (p?['seen'] as num?)?.toInt() ?? 0;
    final total = (p?['total'] as num?)?.toInt() ?? c.questionCount;
    final started = taught > 0 || seen > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _open(context, c.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第${c.order}章',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary),
                        ),
                        Text(
                          c.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink),
                        ),
                        const SizedBox(height: 2),
                        Text('${c.topics.length}テーマ・論点${c.pointCount}・${c.questionCount}問・図解${c.figureCount}枚', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                        const SizedBox(height: 8),
                        ProgressBar(value: points == 0 ? 0 : taught / points),
                        if (started) ...[
                          const SizedBox(height: 4),
                          Text(
                            '説明済み $taught/$points・解いた問題 $seen/$total',
                            style: const TextStyle(fontSize: 12, color: Palette.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Palette.inkFaint),
                ],
              ),
            ),
          ),
          // 会話で学んだ章の過去問へ（過去問のタブの「章ごと」と同じ）
          if (kakomon > 0)
            InkWell(
              onTap: () {
                final state = AppScope.read(context);
                openKakomon(context, set: c.id, label: '第${c.order}章', pointTitle: c.short.isNotEmpty ? c.short : c.title).then((_) => state.refresh());
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, size: 20, color: Palette.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('この章の過去問を解く（$kakomon問）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.primary))),
                    const Icon(Icons.chevron_right, size: 20, color: Palette.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
