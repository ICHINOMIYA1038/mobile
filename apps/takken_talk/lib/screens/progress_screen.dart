import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/pass_score_ring.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final p = me.progress;
    final theme = Theme.of(context);
    final acc = p.accuracy == null ? '—' : '${(p.accuracy! * 100).round()}%';
    return Scaffold(
      appBar: AppBar(title: const Text('進捗'), backgroundColor: theme.scaffoldBackgroundColor),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    PassScoreRing(score: p.passScore, size: 88),
                    const SizedBox(width: 20),
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
            Text('「定着」は同じ問題に2回連続で正解した状態です。間違えた問題は10分後、正解した問題は1日→3日→…と間隔を空けて再出題します。',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 20),
            Text('章ごと', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final c in me.chapters)
              Builder(builder: (context) {
                final cp = p.of(c.id);
                final total = cp?.total ?? c.questionCount;
                final mastered = cp?.mastered ?? 0;
                final seen = cp?.seen ?? 0;
                final a = cp?.accuracy;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('第${c.order}章 ${c.short}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                          Text(
                            a == null ? '未着手' : '正答率 ${(a * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            LinearProgressIndicator(
                              value: total == 0 ? 0 : seen / total,
                              minHeight: 8,
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                            LinearProgressIndicator(
                              value: total == 0 ? 0 : mastered / total,
                              minHeight: 8,
                              color: theme.colorScheme.primary,
                              backgroundColor: Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('定着 $mastered ・ 出題 $seen ・ 全 $total問', style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              }),
          ],
        ),
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
