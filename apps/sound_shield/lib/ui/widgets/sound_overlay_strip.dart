import 'package:flutter/material.dart';

import '../../logic/sound_category.dart';
import '../../logic/sound_timeline_resolver.dart';
import '../../models/sound_segment.dart';

/// 時間軸グラフに重ね合わせる「何の音だったか」の帯と凡例。
class SoundOverlayStrip extends StatelessWidget {
  const SoundOverlayStrip({
    super.key,
    required this.segments,
    required this.durationSeconds,
  });

  final List<SoundSegment> segments;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    final runs = resolveSoundTimeline(segments, durationSeconds.toDouble());
    if (runs.isEmpty) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final unknownColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);

    final barChildren = <Widget>[];
    for (final run in runs) {
      final span = run.end - run.start;
      if (span <= 0) continue;
      if (barChildren.isNotEmpty) {
        barChildren.add(const SizedBox(width: 2));
      }
      barChildren.add(
        Expanded(
          flex: (span * 1000).round().clamp(1, 1 << 30),
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: run.category?.color(brightness) ?? unknownColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }

    final present = <SoundCategory?>{for (final run in runs) run.category};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(children: barChildren),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final category in SoundCategory.values)
              if (present.contains(category))
                _LegendChip(color: category.color(brightness), label: category.label),
            if (present.contains(null))
              _LegendChip(color: unknownColor, label: '未分類'),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
