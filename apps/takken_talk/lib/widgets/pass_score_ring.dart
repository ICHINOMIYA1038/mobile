import 'package:flutter/material.dart';

class PassScoreRing extends StatelessWidget {
  const PassScoreRing({super.key, required this.score, this.size = 96});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score >= 70
        ? const Color(0xFF2E7D32)
        : score >= 40
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            strokeWidth: size / 12,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$score', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color, height: 1)),
                Text('/100', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
