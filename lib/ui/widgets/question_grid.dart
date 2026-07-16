import 'package:flutter/material.dart';

import '../../logic/study_controller.dart';
import '../../models/review_state.dart';
import '../theme.dart';

/// 収録している全問題を1マスずつ並べ、解くほど濃くなる盤面。
///
/// 問題数の科目内訳は本試験の配点比率と一致させてあるため（宅建業法120/権利関係84/
/// 法令上の制限48/税その他48 = 20:14:8:8）、**マス目の面積がそのまま配点比率になる**。
/// 「宅建業法の面積が一番広い＝ここが一番点になる」を説明せずに伝えられるのが狙いで、
/// 棒グラフより多くの情報を同じ場所に収められる。
class QuestionGrid extends StatelessWidget {
  const QuestionGrid({super.key, required this.stats});

  final List<CategoryStats> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in stats) ...[
          _CategorySection(stats: s),
          const SizedBox(height: 18),
        ],
        const _Legend(),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.stats});

  final CategoryStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(stats.category.label, style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '本試験${stats.category.weight}問',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              stats.answered == 0 ? '—' : '正答率 ${(stats.accuracy * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          // 300個のマスを1つずつ読み上げても意味がないので、まとめて要約する。
          label: '${stats.category.label}は${stats.total}問中'
              '${stats.mastered}問が定着、${stats.answered}問が回答済みです。',
          excludeSemantics: true,
          child: _Cells(levels: stats.levels),
        ),
        const SizedBox(height: 6),
        Text(
          '${stats.total}問中 ${stats.mastered}問 定着',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// マス目そのもの。300個並ぶため、1マスは軽い Container に留める。
class _Cells extends StatelessWidget {
  const _Cells({required this.levels});

  final List<MasteryLevel> levels;

  static const _cell = 11.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: _gap,
      runSpacing: _gap,
      children: [
        for (final level in levels)
          Container(
            width: _cell,
            height: _cell,
            decoration: BoxDecoration(
              color: masteryColor(scheme, level),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
      ],
    );
  }
}

/// 凡例。色の意味が分からないと盤面はただの模様になる。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 濃さの段階（薄い→濃い）と、弱点を示す色を分けて並べる。
    const gradation = [
      MasteryLevel.untouched,
      MasteryLevel.learning,
      MasteryLevel.familiar,
      MasteryLevel.mastered,
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '未学習',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            for (final level in gradation) ...[
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: masteryColor(scheme, level),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text(
              '定着',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: masteryColor(scheme, MasteryLevel.needsReview),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '要復習',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
