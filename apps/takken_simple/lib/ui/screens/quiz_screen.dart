import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/terms_data.dart';
import '../../logic/study_controller.dart';
import '../../main.dart';
import '../../models/term.dart';
import '../theme.dart';
import 'result_screen.dart';
import 'term_detail_screen.dart';
import '../widgets/highlighted_text.dart';

/// 出題画面。1画面に1問だけ。広告も、他の導線も置かない。
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);
    final question = controller.current;
    final result = controller.result;

    if (question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final solved = controller.session.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: '終了',
          onPressed: () => _finish(context, controller),
        ),
        title: Text('$solved問'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryChip(
                      category: question.category,
                      topic: question.topic,
                    ),
                    const SizedBox(height: 24),
                    HighlightedText(
                      text: question.statement,
                      style:
                          Theme.of(context).textTheme.bodyLarge ??
                          const TextStyle(),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 28),
                      _Explanation(result: result),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: result == null
                  ? _AnswerButtons(onAnswer: controller.answer)
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: controller.sessionGoalReached
                            ? () => _finish(context, controller)
                            : controller.next,
                        icon: Icon(
                          controller.sessionGoalReached
                              ? Icons.flag_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          controller.sessionGoalReached ? '結果を見る' : '次の問題へ',
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _finish(BuildContext context, StudyController controller) {
    // 1問も解いていなければ結果画面を挟まずホームに戻る。
    if (controller.session.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    // 次の復習日にお知らせを出せるよう予定を組み直す。待たずに画面を進めてよい。
    unawaited(controller.finishSession());
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen()));
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.topic});

  final String category;
  final String topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (categoryColor, categoryBg) = switch (category) {
      '宅建業法' => (const Color(0xFF2E7D5B), const Color(0xFFE8F5E9)),
      '権利関係' => (const Color(0xFF2F5D8A), const Color(0xFFE3F2FD)),
      '法令上の制限' => (const Color(0xFFC57B1E), const Color(0xFFFFF3E0)),
      _ => (theme.colorScheme.primary, theme.colorScheme.primaryContainer),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? categoryColor.withValues(alpha: 0.2) : categoryBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: categoryColor.withValues(alpha: isDark ? 0.4 : 0.2),
          ),
        ),
        child: Text(
          '$category ・ $topic',
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark
                ? categoryColor.withValues(alpha: 0.9)
                : categoryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// ○×の2択。タップ領域を大きくとり、片手で押せる位置に置く。
class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.onAnswer});

  final Future<void> Function(bool) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            label: '○',
            caption: '正しい',
            color: maruColor,
            onTap: () => onAnswer(true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _BigButton(
            label: '×',
            caption: '誤り',
            color: batsuColor,
            onTap: () => onAnswer(false),
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: -10,
                    bottom: -20,
                    child: ExcludeSemantics(
                      child: RichText(
                        text: TextSpan(
                          text: label,
                          style: TextStyle(
                            fontSize: 100,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.15),
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 解説。正誤の判定は色と一語で伝え、理由は必ず読ませる。
class _Explanation extends StatelessWidget {
  const _Explanation({required this.result});

  final AnswerResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final correct = result.isCorrect;
    final color = correct ? maruColor : batsuColor;

    final relatedTerms = extractRelatedTerms(
      result.question.statement + result.question.explanation,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.4 : 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.05 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          correct
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        correct ? '正解！' : '不正解...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '答えは ${result.question.answer ? '○' : '×'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              HighlightedText(
                text: result.question.explanation,
                style:
                    theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.8,
                    ) ??
                    const TextStyle(fontSize: 16, height: 1.8),
              ),
              if (relatedTerms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '下線付きの言葉をタップすると、用語解説を開きます。',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 28),
              Row(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      result.question.reference,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (!correct) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.replay_rounded, color: color, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'この問題は後でもう一度出題されます。',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (relatedTerms.isNotEmpty) ...[
          const SizedBox(height: 24),
          _RelatedTermsSection(terms: relatedTerms),
        ],
      ],
    );
  }
}

class _RelatedTermsSection extends StatelessWidget {
  const _RelatedTermsSection({required this.terms});

  final List<Term> terms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'この問題の重要用語',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: terms.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final term = terms[index];
            final (categoryColor, categoryBg) = switch (term.category) {
              '宅建業法' => (const Color(0xFF2E7D5B), const Color(0xFFE8F5E9)),
              '権利関係' => (const Color(0xFF2F5D8A), const Color(0xFFE3F2FD)),
              '法令上の制限' => (const Color(0xFFC57B1E), const Color(0xFFFFF3E0)),
              _ => (
                theme.colorScheme.primary,
                theme.colorScheme.primaryContainer,
              ),
            };

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TermDetailScreen(term: term),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'term-title-${term.id}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        term.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? categoryColor.withValues(alpha: 0.2)
                                          : categoryBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      term.category,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isDark
                                                ? categoryColor.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : categoryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                term.shortDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
