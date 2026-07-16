import 'package:flutter/material.dart';

import '../../logic/study_controller.dart';
import '../../main.dart';
import '../theme.dart';
import 'result_screen.dart';

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
                    _CategoryChip(category: question.category, topic: question.topic),
                    const SizedBox(height: 24),
                    Text(question.statement, style: Theme.of(context).textTheme.bodyLarge),
                    if (result != null) ...[
                      const SizedBox(height: 28),
                      _Explanation(result: result),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: result == null
                  ? _AnswerButtons(onAnswer: controller.answer)
                  : FilledButton(
                      onPressed: controller.next,
                      child: const Text('次の問題へ'),
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.topic});

  final String category;
  final String topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$category ・ $topic',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
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
        const SizedBox(width: 12),
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
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
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
    final correct = result.isCorrect;
    final color = correct ? maruColor : batsuColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? '正解' : '不正解',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '答えは ${result.question.answer ? '○' : '×'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.question.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 12),
          Text(
            result.question.reference,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!correct) ...[
            const SizedBox(height: 12),
            Text(
              'この問題は後でもう一度出します。',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
