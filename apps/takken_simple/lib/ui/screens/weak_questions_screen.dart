import 'package:flutter/material.dart';

import '../../main.dart';
import 'quiz_screen.dart';

class WeakQuestionsScreen extends StatelessWidget {
  const WeakQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.of(context);
    final questions = controller.weakQuestions;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('苦手問題')),
      body: SafeArea(
        child: questions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'いま復習が必要な問題はありません。\n間違えた問題はここに追加されます。',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      '直近で間違え、まだ正解し直していない ${questions.length}問です。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(
                              question.statement,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${question.category}・${question.topic}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton.icon(
                      onPressed: () {
                        controller.startWeakSession();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'quiz'),
                            builder: (_) => const QuizScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text('苦手問題を復習（${questions.length}問）'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
