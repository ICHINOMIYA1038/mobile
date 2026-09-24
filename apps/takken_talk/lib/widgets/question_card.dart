import 'package:flutter/material.dart';

import '../models.dart';

/// 会話の中に出てくる○×カード。answered が null なら回答待ち。
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.answered,
    required this.correct,
    required this.enabled,
    required this.onAnswer,
  });
  final PublicQuestion question;
  final bool? answered;
  final bool? correct;
  final bool enabled;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = answered != null;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(question.topic, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              const Spacer(),
              Text('難易度 ${'★' * question.difficulty}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.statement, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 12),
          if (!done)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled ? () => onAnswer(true) : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: const Text('○ 正しい', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled ? () => onAnswer(false) : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: const Text('× 誤り', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  correct == true ? Icons.check_circle : Icons.cancel,
                  color: correct == true ? const Color(0xFF2E7D32) : theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${answered! ? '○' : '×'} と回答 → ${correct == true ? '正解' : '不正解'}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
