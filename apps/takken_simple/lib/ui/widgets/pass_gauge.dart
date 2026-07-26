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
    final isDark = theme.brightness == Brightness.dark;
    final reached = score >= StudyController.passingScore;
    final remaining = (StudyController.passingScore - score).clamp(0.0, _fullScore);

    return Semantics(
      label: '本試験の配点で換算した予想得点は50点満点中${score.toStringAsFixed(1)}点。'
          '合格ラインの目安は${StudyController.passingScore.toInt()}点。'
          '${reached ? '目安に届いています。' : 'あと${remaining.toStringAsFixed(1)}点です。'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '本試験の配点で換算した予想得点',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ScoreText(score: score, reached: reached),
              const SizedBox(height: 20),
              _Bar(score: score),
              const SizedBox(height: 14),
              Text(
                answered == 0
                    ? '1問解くごとにバーが伸びます'
                    : reached
                        ? '🎉 合格ラインの目安に届いています！'
                        : '合格目安まで あと ${remaining.toStringAsFixed(1)}点',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: reached ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
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
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 48,
            ),
          ),
          TextSpan(
            text: ' / 50点',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = (score / PassGauge._fullScore).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: _height + 6,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 目盛りの土台（0〜50点）
                  Positioned(
                    top: 3,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: _height,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(_height / 2),
                      ),
                    ),
                  ),
                  // 現在の得点。解くほど伸びる。
                  Positioned(
                    top: 3,
                    left: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      width: width * ratio,
                      height: _height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.8),
                            scheme.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(_height / 2),
                      ),
                    ),
                  ),
                  // 合格ラインの目印。縦のラインと丸いピンで目立たせる。
                  Positioned(
                    left: width * _passRatio - 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * _passRatio - 5,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: scheme.onSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // 目印の真下に合格ラインのラベルを置く。
        Align(
          alignment: const Alignment(_passRatio * 2 - 1, 0),
          child: Text(
            '合格ライン ${StudyController.passingScore.toInt()}点',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
