import 'package:flutter/material.dart';

import '../../logic/study_controller.dart';
import '../../main.dart';
import '../../models/question.dart';
import 'glossary_screen.dart';
import 'quiz_screen.dart';
import 'stats_screen.dart';

/// ホーム画面。
/// クイック出題と分野から出題の二つのボタン、そして正答数/総問題数のみを表示するシンプルなUI。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);

    if (controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (controller.loadFailed || controller.totalQuestions == 0) {
      return _LoadFailed(controller: controller);
    }

    final correct = controller.correctlyAnsweredCount;
    final total = controller.totalQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('シンプルに学ぶ宅建'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: '重要用語集',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: '成績',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 3),
                      _ProgressHeader(
                        correct: correct,
                        total: total,
                        due: controller.dueCount,
                      ),
                      const SizedBox(height: 20),
                      const _AutomaticStudyNote(),
                      const Spacer(flex: 3),
                      // 正方形ボタン横並び
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _SquareButton(
                                icon: Icons.flash_on_rounded,
                                label: controller.dueCount > 0
                                    ? '今日の復習'
                                    : '5問はじめる',
                                filled: true,
                                onTap: () {
                                  controller.startSession();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const QuizScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SquareButton(
                                icon: Icons.category_rounded,
                                label: '分野から出題',
                                filled: false,
                                onTap: () =>
                                    _showCategorySelection(context, controller),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCategorySelection(
    BuildContext context,
    StudyController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CategorySelectionSheet(controller: controller),
    );
  }
}

/// 分野（大区分・中区分）を二段階で選択できる状態管理シート。
class _CategorySelectionSheet extends StatefulWidget {
  const _CategorySelectionSheet({required this.controller});

  final StudyController controller;

  @override
  State<_CategorySelectionSheet> createState() =>
      _CategorySelectionSheetState();
}

class _CategorySelectionSheetState extends State<_CategorySelectionSheet> {
  Category? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _selectedCategory;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: category == null
              ? _buildCategoryList(theme)
              : _buildMediumCategoryList(theme, category),
        ),
      ),
    );
  }

  Widget _buildCategoryList(ThemeData theme) {
    return Column(
      key: const ValueKey('categories'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '分野を選択（大区分）',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ...Category.values.map((category) {
          final correct = widget.controller.correctCountForCategory(
            category.label,
          );
          final total = widget.controller.totalCountForCategory(category.label);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$correct / $total 問',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMediumCategoryList(ThemeData theme, Category category) {
    // 各大区分に属する中区分の定義
    final List<String> mediumCategories = switch (category.label) {
      '宅建業法' => ['免許・宅建士・保証制度', '業務上の規制（35条・37条等）', '契約・報酬・8種制限・罰則'],
      '権利関係' => ['契約・意思表示・代理', '債権・不法行為・相続', '所有権・借地借家・不動産登記'],
      '法令上の制限' => ['都市計画法', '建築基準法', 'その他の法令（農地法等）'],
      _ => ['地方税・国税', '価格公示・鑑定・業務関連'],
    };

    return Column(
      key: ValueKey('medium-categories-${category.label}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
              tooltip: '戻る',
            ),
            Expanded(
              child: Text(
                category.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // IconButtonの幅と揃えて中央配置にするためのスペース
          ],
        ),
        const SizedBox(height: 20),
        ...mediumCategories.map((mediumCategory) {
          final correct = widget.controller.correctCountForMediumCategory(
            category.label,
            mediumCategory,
          );
          final total = widget.controller.totalCountForMediumCategory(
            category.label,
            mediumCategory,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.controller.startSession(
                    categoryLabel: category.label,
                    mediumCategoryLabel: mediumCategory,
                  );
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QuizScreen()));
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mediumCategory,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            '$correct / $total 問',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// 読み込みに失敗したときの画面。
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.controller});

  final StudyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('シンプルに学ぶ宅建')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '問題を読み込めませんでした',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'アプリを開き直しても直らない場合は、学習履歴を消すと復旧することがあります。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: controller.init,
                child: const Text('再試行'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await controller.resetProgress();
                  await controller.init();
                },
                child: Text(
                  '学習履歴を消してやり直す',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正答数/総問題数を表示するヘッダー。
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.correct,
    required this.total,
    required this.due,
  });

  final int correct;
  final int total;
  final int due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          due > 0 ? '今日の復習 $due問' : '正答した問題',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$correct',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 64,
                ),
              ),
              TextSpan(
                text: ' / $total 問',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutomaticStudyNote extends StatelessWidget {
  const _AutomaticStudyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '忘れかけた問題と、配点の高い分野から自動で出題します',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 正方形のカードスタイルボタン。
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final backgroundColor = filled
        ? primary
        : theme.colorScheme.surfaceContainerLow;
    final foregroundColor = filled ? theme.colorScheme.onPrimary : primary;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: filled ? null : Border.all(color: primary, width: 2),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: foregroundColor),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
