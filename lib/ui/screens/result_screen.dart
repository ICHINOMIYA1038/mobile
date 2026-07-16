import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme.dart';
import '../widgets/result_banner_ad.dart';

/// セッションの結果。褒めも煽りもせず、事実と次にやることだけを示す。
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);
    final purchases = PurchaseScope.of(context);
    final theme = Theme.of(context);
    final session = controller.session;
    final correct = session.where((r) => r.isCorrect).length;
    final wrong = session.where((r) => !r.isCorrect).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('おつかれさまでした'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Text('${session.length}問中', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(
                            '$correct問 正解',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wrong.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '間違えた問題',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'これらは忘れかけた頃に自動で出します。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...wrong.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(color: batsuColor, width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.question.category} ・ ${r.question.topic}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.question.statement,
                                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 広告はこの結果画面にだけ置く。出題中・解説中には絶対に出さない。
            ResultBannerAd(adsRemoved: purchases.adsRemoved),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('ホームに戻る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
