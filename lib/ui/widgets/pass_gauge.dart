import 'package:flutter/material.dart';

import '../../logic/study_controller.dart';

/// 合格までの距離を1本のバーで見せる。
///
/// 「正答率○%」ではなく本試験の配点で換算した得点を、合格ラインの目印つきで示す。
/// 解くほどバーが伸びて目印に近づくため、積み上げが合格に直結していることが目で分かる。
class PassGauge extends StatelessWidget {
  const PassGauge({super.key, required this.score, required this.answered});

  /// 本試験の配点で換算した予想得点（50点満点）。
  final double score;

  /// 回答済みの問題数。0なら説明を出す。
  final int answered;

  static const _fullScore = 50.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reached = score >= StudyController.passingScore;
    final remaining = (StudyController.passingScore - score).clamp(0.0, _fullScore);

    return Semantics(
      // バーの形は読み上げられないため、数値で同じ情報を伝える。
      label: '本試験の配点で換算した予想得点は50点満点中${score.toStringAsFixed(1)}点。'
          '合格ラインの目安は${StudyController.passingScore.toInt()}点。'
          '${reached ? '目安に届いています。' : 'あと${remaining.toStringAsFixed(1)}点です。'}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '本試験の配点で換算した予想得点',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _ScoreText(score: score, reached: reached),
              const SizedBox(height: 18),
              _Bar(score: score),
              const SizedBox(height: 10),
              Text(
                answered == 0
                    ? '1問解くごとにバーが伸びます'
                    : reached
                        ? '合格ラインの目安に届いています'
                        : 'あと ${remaining.toStringAsFixed(1)}点',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: reached ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: reached ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreText extends StatelessWidget {
  const _ScoreText({required this.score, required this.reached});

  final double score;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: score.toStringAsFixed(1),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          TextSpan(
            text: ' / 50点',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 0〜50点のバー。合格ラインの位置に目印を立てる。
class _Bar extends StatelessWidget {
  const _Bar({required this.score});

  final double score;

  static const _height = 14.0;
  static const _passRatio = StudyController.passingScore / PassGauge._fullScore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (score / PassGauge._fullScore).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: _height,
              child: Stack(
                children: [
                  // 目盛りの土台（0〜50点）
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                  // 現在の得点。解くほど伸びる。
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: width * ratio,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                  // 合格ラインの目印。ここが目的地。
                  Positioned(
                    left: width * _passRatio - 1,
                    top: -3,
                    bottom: -3,
                    child: Container(width: 2, color: scheme.onSurface),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // 目印の真下に合格ラインのラベルを置く。
        Align(
          alignment: const Alignment(_passRatio * 2 - 1, 0),
          child: Text(
            '合格ライン ${StudyController.passingScore.toInt()}点',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
