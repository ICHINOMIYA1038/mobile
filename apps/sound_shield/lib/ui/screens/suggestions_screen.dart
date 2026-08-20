import 'package:flutter/material.dart';

import '../../logic/sound_category.dart';
import '../../logic/sound_label_localizer.dart';
import '../../logic/suggestion_engine.dart';
import '../../models/measurement_result.dart';
import '../widgets/suggestion_card.dart';

/// 検出音の内訳と対策の提案をまとめた画面。[ResultScreen]の「対策を見る」から遷移する。
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key, required this.result});

  final MeasurementResult result;

  @override
  Widget build(BuildContext context) {
    final suggestions = const SuggestionEngine().suggest(result);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('対策')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (result.soundLabels.isNotEmpty) ...[
              Text('検出された音', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final label in result.soundLabels.take(3))
                _SoundItem(
                  color:
                      categoryForIdentifier(label.identifier)?.color(brightness) ??
                      scheme.outline.withValues(alpha: 0.3),
                  name: describeSoundLabel(label.identifier),
                  sharePercent: (label.activeShare * 100).round(),
                ),
              const SizedBox(height: 24),
            ],
            Text('おすすめの対策', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final suggestion in suggestions)
              SuggestionCard(suggestion: suggestion),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('ホームに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundItem extends StatelessWidget {
  const _SoundItem({
    required this.color,
    required this.name,
    required this.sharePercent,
  });

  final Color color;
  final String name;
  final int sharePercent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.graphic_eq, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$sharePercent%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
