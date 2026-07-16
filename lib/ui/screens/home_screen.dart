import 'package:flutter/material.dart';

import '../../main.dart';
import 'quiz_screen.dart';
import 'stats_screen.dart';

/// ホーム。ボタンは実質1つだけ。迷う余地をなくす。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);
    final theme = Theme.of(context);

    if (controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final due = controller.dueCount;
    final streak = controller.streak.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('シンプルに学ぶ宅建'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: '成績',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              _TodayCard(due: due, newCount: controller.newCount),
              const SizedBox(height: 16),
              if (streak > 0)
                Text(
                  '$streak日連続で学習中',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  controller.startSession();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QuizScreen()),
                  );
                },
                child: Text(due > 0 ? '復習をはじめる' : '学習をはじめる'),
              ),
              const SizedBox(height: 12),
              Text(
                '出題する問題はアプリが自動で選びます。\n設定は要りません。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日やることを1枚に集約。ここに数字を並べすぎない。
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.due, required this.newCount});

  final int due;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Text(
              due > 0 ? '今日の復習' : 'はじめての問題',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${due > 0 ? due : newCount}',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            Text('問', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              due > 0
                  ? '忘れかけている頃です。今やると定着します。'
                  : 'まずは1問。宅建業法から順に出します。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
