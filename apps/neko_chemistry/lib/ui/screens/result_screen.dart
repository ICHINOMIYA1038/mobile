import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../logic/quiz_controller.dart';
import '../widgets/cat_mascot.dart' show CatAccessory;
import '../widgets/result_cat_show.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    this.accessory = CatAccessory.none,
  });

  final QuizController controller;
  final CatAccessory accessory;

  @override
  Widget build(BuildContext context) {
    final total = controller.totalCount;
    final score = controller.score;
    final ratio = total == 0 ? 0.0 : score / total;

    return Scaffold(
      appBar: AppBar(title: const Text('結果')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResultCatShow(ratio: ratio, accessory: accessory),
              const SizedBox(height: 24),
              Text(
                '$score / $total 問正解!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _comment(score, total),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Share.share(
                        '「猫と学ぶ高校化学」で$score/$total問正解しました!🐱',
                        subject: '猫と学ぶ高校化学の結果',
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('シェア'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      controller.restart();
                      Navigator.of(context).pop();
                    },
                    child: const Text('もう一度'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _comment(int score, int total) {
    final ratio = total == 0 ? 0 : score / total;
    if (ratio >= 0.8) return 'にゃんと素晴らしい!化学マスターだね';
    if (ratio >= 0.5) return 'いい調子!もう少しで完璧';
    return 'にゃー、次はもっと解けるはず';
  }
}
