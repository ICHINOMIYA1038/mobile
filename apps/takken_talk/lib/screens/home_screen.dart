import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/pass_score_ring.dart';
import 'chat_screen.dart';
import 'paywall_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [_HomeTab(), ProgressScreen(), SettingsScreen()];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '学ぶ'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '進捗'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  void _openChapter(BuildContext context, Chapter c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(chapterId: c.id), settings: RouteSettings(name: 'chat_${c.id}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final theme = Theme.of(context);
    final p = me.progress;
    final lastId = me.lastChapterId ?? 'ch01';
    final last = me.chapter(lastId) ?? me.chapters.first;
    final canUseLocked = me.plan.isPro || me.plan.turnBalance > 0;

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('話して受かる宅建'),
            backgroundColor: theme.scaffoldBackgroundColor,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        PassScoreRing(score: p.passScore, size: 96),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('合格見込みスコア', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 4),
                              Text(
                                p.daysToExam == null
                                    ? '試験日を設定すると残り日数が出ます'
                                    : p.daysToExam! >= 0
                                        ? '試験まで あと${p.daysToExam}日'
                                        : '試験日を過ぎています。設定から更新を',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('定着 ${p.mastered}/${p.totalQuestions}問', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openChapter(context, last),
                  icon: const Icon(Icons.chat),
                  label: Text(me.turnCounts.isEmpty ? '第${last.order}章を始める' : '第${last.order}章の続きを話す'),
                ),
                if (!me.plan.isPro) ...[
                  const SizedBox(height: 8),
                  _PlanStrip(plan: me.plan),
                ],
                const SizedBox(height: 20),
                Text('カリキュラム', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final c in me.chapters)
                  _ChapterTile(
                    chapter: c,
                    progress: p.of(c.id),
                    turns: me.turnCounts[c.id] ?? 0,
                    locked: !c.free && !canUseLocked,
                    onTap: () {
                      if (!c.free && !canUseLocked) {
                        PaywallScreen.show(context, reason: 'locked');
                      } else {
                        _openChapter(context, c);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                Text('AIの説明は誤りを含むことがあります。数字や最新の法改正は必ずテキスト・公式情報で確認してください。',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStrip extends StatelessWidget {
  const _PlanStrip({required this.plan});
  final PlanInfo plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = plan.turnBalance > 0
        ? '会話パック 残り${plan.turnBalance}回'
        : '無料枠 残り${plan.freeLeft}回（第1章）';
    return InkWell(
      onTap: () => PaywallScreen.show(context, reason: 'strip'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.bolt, size: 18, color: theme.colorScheme.tertiary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
            Text('Proを見る', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.progress,
    required this.turns,
    required this.locked,
    required this.onTap,
  });
  final Chapter chapter;
  final ChapterProgress? progress;
  final int turns;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = progress?.total ?? chapter.questionCount;
    final mastered = progress?.mastered ?? 0;
    final ratio = total == 0 ? 0.0 : mastered / total;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('第${chapter.order}章 ・ ${chapter.subject}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 2),
                    Text(chapter.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: theme.colorScheme.surfaceContainerHighest),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$mastered/$total', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (locked)
                Icon(Icons.lock_outline, color: theme.colorScheme.outline)
              else if (chapter.free && turns == 0)
                Chip(
                  label: const Text('無料'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  side: BorderSide.none,
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
