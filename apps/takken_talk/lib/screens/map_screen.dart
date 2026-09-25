import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/readable.dart';
import '../widgets/pass_score_ring.dart';
import 'chat_screen.dart';
import 'figure_library_screen.dart';
import 'paywall_screen.dart';

/// 学習の地図。4科目 → 11章 → 53テーマを一枚で見せる。
/// 「何を学ぶのか」と「どこまで進んだか」を同じ画面で確かめられるようにしている。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final p = me.progress;
    final theme = Theme.of(context);
    final acc = p.accuracy == null ? '—' : '${(p.accuracy! * 100).round()}%';
    final subjects = me.subjects;
    final totalTopics = me.chapters.fold<int>(0, (a, c) => a + c.topics.length);
    final canUseLocked = me.plan.isPro || me.plan.turnBalance > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学習の地図'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: '図解ライブラリ',
            icon: const Icon(Icons.image_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FigureLibraryScreen(),
              settings: const RouteSettings(name: 'figure_library'),
            )),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: Readable(
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    PassScoreRing(score: p.passScore, size: 84),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Stat(label: '出題した問題', value: '${p.seen} / ${p.totalQuestions}'),
                          _Stat(label: '定着した問題', value: '${p.mastered}'),
                          _Stat(label: '正答率', value: acc),
                          if (p.daysToExam != null) _Stat(label: '試験まで', value: 'あと${p.daysToExam}日'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '全体で ${me.chapters.length}章・$totalTopicsテーマ・${p.totalQuestions}問。'
              '「定着」は同じ問題に2回続けて正解した状態です。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, height: 1.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FigureLibraryScreen(),
                settings: const RouteSettings(name: 'figure_library'),
              )),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text('図解ライブラリ（${me.chapters.fold<int>(0, (a, c) => a + c.figureCount)}枚）を見る'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            const SizedBox(height: 20),
            for (final s in subjects) ...[
              _SubjectBlock(subject: s, progress: p),
              for (final id in s.chapterIds)
                if (me.chapter(id) case final c?)
                  _ChapterNode(
                    chapter: c,
                    progress: p.of(c.id),
                    currentTopicKey: me.currentTopics[c.id],
                    visited: me.visitedTopics,
                    expanded: _expanded.contains(c.id),
                    locked: !c.free && !canUseLocked,
                    onToggle: () => setState(() {
                      if (!_expanded.remove(c.id)) _expanded.add(c.id);
                    }),
                    onOpenChat: () {
                      if (!c.free && !canUseLocked) {
                        PaywallScreen.show(context, reason: 'locked');
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(chapterId: c.id),
                          settings: RouteSettings(name: 'chat_${c.id}'),
                        ));
                      }
                    },
                    onOpenFigures: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FigureLibraryScreen(chapter: c),
                      settings: RouteSettings(name: 'figures_${c.id}'),
                    )),
                  ),
              const SizedBox(height: 18),
            ],
          ],
          ),
        ),
      ),
    );
  }
}

class _SubjectBlock extends StatelessWidget {
  const _SubjectBlock({required this.subject, required this.progress});
  final Subject subject;
  final ProgressSummary progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var total = 0, mastered = 0, seen = 0;
    for (final id in subject.chapterIds) {
      final cp = progress.of(id);
      if (cp == null) continue;
      total += cp.total;
      mastered += cp.mastered;
      seen += cp.seen;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(subject.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('${subject.examQuestions}問',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('定着 $mastered / $total', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? 0 : seen / total,
                  minHeight: 7,
                  color: theme.colorScheme.primary.withValues(alpha: 0.28),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : mastered / total,
                  minHeight: 7,
                  color: theme.colorScheme.primary,
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  const _ChapterNode({
    required this.chapter,
    required this.progress,
    required this.currentTopicKey,
    required this.visited,
    required this.expanded,
    required this.locked,
    required this.onToggle,
    required this.onOpenChat,
    required this.onOpenFigures,
  });
  final Chapter chapter;
  final ChapterProgress? progress;
  final String? currentTopicKey;
  final Set<String> visited;
  final bool expanded;
  final bool locked;
  final VoidCallback onToggle;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenFigures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('第${chapter.order}章', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        Text(chapter.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
                        const SizedBox(height: 4),
                        Text('${chapter.topics.length}テーマ ・ ${chapter.questionCount}問 ・ 図解${chapter.figureCount}枚',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  if (locked) Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.outline),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, color: theme.colorScheme.outlineVariant, margin: const EdgeInsets.only(bottom: 10)),
                  Text(chapter.goal, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                  const SizedBox(height: 12),
                  for (final (i, t) in chapter.topics.indexed)
                    _TopicRow(
                      index: i + 1,
                      topic: t,
                      progress: progress?.topic(t.key),
                      isCurrent: t.key == currentTopicKey,
                      visited: visited.contains('${chapter.id}/${t.key}'),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenFigures,
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: Text('図解 ${chapter.figureCount}枚'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onOpenChat,
                          icon: Icon(locked ? Icons.lock_outline : Icons.chat_bubble_outline, size: 18),
                          label: const Text('話す'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.index,
    required this.topic,
    required this.progress,
    required this.isCurrent,
    required this.visited,
  });
  final int index;
  final ChapterTopic topic;
  final TopicProgress? progress;
  final bool isCurrent;
  final bool visited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mastered = progress?.mastered ?? 0;
    final total = progress?.total ?? topic.questionCount;
    final ratio = total == 0 ? 0.0 : mastered / total;
    final color = ratio >= 0.8
        ? const Color(0xFF2E7D32)
        : ratio > 0
            ? theme.colorScheme.primary
            : visited
                ? theme.colorScheme.tertiary
                : theme.colorScheme.outlineVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.07) : null,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: ratio > 0 ? 1 : 0.4), shape: BoxShape.circle),
            child: ratio >= 0.8
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Text('$index', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              topic.title,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('$mastered/$total', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
