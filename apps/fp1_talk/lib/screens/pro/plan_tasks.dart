import 'package:flutter/material.dart';

import '../../main.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../common/parts.dart';
import 'mock_screen.dart';

// 学習プランの「7日の予定」のタスク（サイトの src/lib/server/pro.ts の PlanTask と withProgress）。
// タスクは押すとその練習が始まり（先生と学ぶ・過去問・復習・模擬試験）、その日の記録から自動で済みになる。丸を押せば自分でも付け外しできる。
// 苦手分析の画面の「7日の予定」と、ホームの「今日の予定」の両方で使う。判断だけの関数は test/plan_tasks_test.dart で確かめる。

const _week = ['月', '火', '水', '木', '金', '土', '日'];

/// 「2026-10-22」→「10/22（木）」
String dateLabel(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return ymd;
  return '${d.month}/${d.day}（${_week[d.weekday - 1]}）';
}

/// 論点 id の頭の章（「ch06-hendo-1」→「ch06」）
String? chapterOfPoint(String? pointId) => pointId == null ? null : RegExp(r'^(ch\d{2})-').firstMatch(pointId)?.group(1);

enum TaskGo { learn, kakomon, review, mock, none }

/// タスクを押したときの行き先（行けないものは none）
({TaskGo go, String? chapterId, String? pointId}) taskRoute(Map<String, dynamic> t) {
  final pointId = t['pointId'] as String?;
  final chapterId = (t['chapterId'] as String?) ?? chapterOfPoint(pointId);
  switch (t['type']) {
    case 'learn':
      return chapterId == null ? (go: TaskGo.none, chapterId: null, pointId: null) : (go: TaskGo.learn, chapterId: chapterId, pointId: pointId);
    case 'kakomon':
      return chapterId == null ? (go: TaskGo.none, chapterId: null, pointId: null) : (go: TaskGo.kakomon, chapterId: chapterId, pointId: pointId);
    case 'review':
      return (go: TaskGo.review, chapterId: null, pointId: null);
    case 'mock':
      return (go: TaskGo.mock, chapterId: null, pointId: null);
  }
  return (go: TaskGo.none, chapterId: null, pointId: null);
}

/// 過去問の画面の見出しの2行目。タスクの文の「」の中（論点の名前）、無ければ null（章の名前にする）
String? kakomonTitle(String text) => RegExp(r'「([^」]+)」').firstMatch(text)?.group(1);

/// タスクの済みを付け外しした形（画面を先に変えるため。失敗したら元の形に戻す）。doneCount も数え直す
List<Map<String, dynamic>> checkedTasks(List<Map<String, dynamic>> tasks, String taskId, bool done) => [
  for (final t in tasks) t['id'] == taskId ? {...t, 'done': done, 'manual': done} : t,
];

/// プラン（week[].tasks）の中の1つを付け外しした形
Map<String, dynamic> checkedPlan(Map<String, dynamic> plan, String taskId, bool done) {
  final week = [
    for (final d in ((plan['week'] as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()))
      () {
        final tasks = checkedTasks(taskList(d), taskId, done);
        return {...d, 'tasks': tasks, 'doneCount': tasks.where((t) => t['done'] == true).length};
      }(),
  ];
  return {...plan, 'week': week};
}

/// 今日の予定（tasks がじかにある形）の1つを付け外しした形
Map<String, dynamic> checkedToday(Map<String, dynamic> today, String taskId, bool done) {
  final tasks = checkedTasks(taskList(today), taskId, done);
  return {...today, 'tasks': tasks, 'doneCount': tasks.where((t) => t['done'] == true).length};
}

List<Map<String, dynamic>> taskList(Map<String, dynamic>? d) => ((d?['tasks'] as List?) ?? const []).map((x) => (x as Map).cast<String, dynamic>()).toList();

/// タスクを始める（その練習の画面を開く）。戻ってきたら終わる（呼んだ側で進み具合を取り直す）
Future<void> startTask(BuildContext context, Map<String, dynamic> t) async {
  final r = taskRoute(t);
  switch (r.go) {
    case TaskGo.learn:
      await openChapter(context, r.chapterId!, pointId: r.pointId);
    case TaskGo.kakomon:
      // FP1 の予定の「過去問」は本試験形式の問（サイトの withProgress は item_log で済みにする）。章のまとまりを開く
      final c = AppScope.read(context).chapter(r.chapterId!);
      await openItems(context, set: r.chapterId!, label: c == null ? r.chapterId! : '第${c.order}章 ${c.short.isNotEmpty ? c.short : c.title}');
    case TaskGo.review:
      // 復習はタブなので、重ねた画面を閉じて「復習」へ
      Shell.show(context, 2);
    case TaskGo.mock:
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MockIntroScreen(), settings: const RouteSettings(name: 'pro_mock')));
    case TaskGo.none:
      break;
  }
}

IconData taskIcon(String? type) => switch (type) {
  'learn' => Icons.forum_outlined,
  'kakomon' => Icons.edit_note,
  'review' => Icons.replay,
  'mock' => Icons.timer_outlined,
  _ => Icons.check_box_outline_blank,
};

/// タスクの1行: 丸（押すと済み・未済み）・種類の印・文・問題数の進み具合。行のほかの所を押すとその練習が始まる
class PlanTaskRow extends StatelessWidget {
  const PlanTaskRow({super.key, required this.task, required this.onToggle, required this.onStart, this.dim = false});
  final Map<String, dynamic> task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onStart;

  /// 過ぎた日（薄く）
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final done = task['done'] == true;
    final goal = (task['goal'] as num?)?.toInt() ?? 1;
    final progress = (task['progress'] as num?)?.toInt() ?? 0;
    final counted = task['type'] == 'kakomon' || task['type'] == 'review';
    final fg = done || dim ? Palette.inkSoft : Palette.ink;
    final canStart = taskRoute(task).go != TaskGo.none;
    return Semantics(
      container: true,
      child: InkWell(
        onTap: canStart ? onStart : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 4, 2),
          child: Row(
            children: [
              CheckCircle(done: done, onTap: () => onToggle(!done), label: task['text'] as String? ?? ''),
              Icon(taskIcon(task['type'] as String?), size: 18, color: done ? Palette.inkFaint : Palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: _motion(context, const Duration(milliseconds: 200)),
                        style: TextStyle(fontSize: 14, height: 1.5, color: fg, decoration: done ? TextDecoration.lineThrough : null, decorationColor: Palette.inkFaint),
                        child: Text(task['text'] as String? ?? ''),
                      ),
                      if (counted && goal > 1) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          Expanded(child: ProgressBar(value: progress / goal, height: 4, color: done ? Palette.success : Palette.primary)),
                          const SizedBox(width: 8),
                          Text('$progress/$goal問', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? Palette.success : Palette.inkSoft, fontFeatures: const [FontFeature.tabularFigures()])),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              if (canStart) Icon(Icons.chevron_right, size: 20, color: done ? Palette.lineStrong : Palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 動きを減らす設定なら動かさない
Duration _motion(BuildContext context, Duration d) => MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;

/// 済みの丸。済みになると緑に塗られ、チェックが少し弾んで出る（動きを減らす設定ならすぐ出す）
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.done, required this.onTap, required this.label});
  final bool done;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    checked: done,
    label: '$label を${done ? '未済みにする' : '済みにする'}',
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: _motion(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOut,
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Palette.success : Palette.paper, border: Border.all(color: done ? Palette.success : Palette.lineStrong, width: 2)),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: _motion(context, const Duration(milliseconds: 380)),
              curve: Curves.elasticOut,
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

/// その日の予定がぜんぶ済んだときの一言
class AllDoneBanner extends StatelessWidget {
  const AllDoneBanner({super.key});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.85, end: 1),
    duration: _motion(context, const Duration(milliseconds: 450)),
    curve: Curves.elasticOut,
    builder: (context, v, child) => Transform.scale(scale: v, child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Palette.successSoft, borderRadius: BorderRadius.circular(8)),
      child: const Row(children: [
        Icon(Icons.celebration_outlined, size: 20, color: Palette.success),
        SizedBox(width: 8),
        Expanded(child: Text('今日の予定、ぜんぶできました', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.success))),
      ]),
    ),
  );
}
