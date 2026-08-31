import 'package:flutter/material.dart';

import '../../logic/inspection_pdf.dart';
import '../../logic/inspection_scorer.dart';
import '../../models/inspection.dart';
import 'home_screen.dart';
import 'inspection_flow_screen.dart';
import 'inspection_list_screen.dart';
import 'simulator_screen.dart';

/// 内見診断の結果。スコア・等級・弱点・壁の推定・各項目の内訳。
class InspectionResultScreen extends StatelessWidget {
  const InspectionResultScreen({super.key, required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final score = const InspectionScorer().score(inspection);
    final scheme = Theme.of(context).colorScheme;
    final color = scoreColor(context, score.score);
    final measurement = inspection.window ?? inspection.ambient ?? inspection.neighbor;

    return Scaffold(
      appBar: AppBar(
        title: Text(inspection.name),
        actions: [
          IconButton(
            tooltip: 'PDFで共有',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Column(
              children: [
                Text(
                  '防音スコア',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: scheme.outline),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.score}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14, left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${score.grade} ・ ${score.gradeLabel}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${score.measuredSteps}/${InspectionStep.values.length}項目を計測 ・ 同じ端末での相対評価',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (score.weakest != null)
              _Callout(
                icon: Icons.warning_amber_rounded,
                color: scheme.tertiary,
                title: '弱点: ${score.weakest!.label}',
                body: score.weakest!.detail,
              ),
            if (inspection.knock != null) ...[
              const SizedBox(height: 12),
              _Callout(
                icon: Icons.apartment_outlined,
                color: scheme.primary,
                title: score.wall.label,
                body: score.wall.description,
              ),
            ],
            const SizedBox(height: 24),
            Text('項目別', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final c in score.components) _ComponentRow(component: c),
            if (score.components.isEmpty)
              Text(
                '計測データがありません。',
                style: TextStyle(color: scheme.outline),
              ),
            const SizedBox(height: 24),
            if (measurement != null)
              FilledButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('効く対策を予測する'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'simulator'),
                    builder: (_) => SimulatorScreen(
                      result: measurement,
                      routes: score.routes,
                      contextLabel: inspection.name,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: const Text('他の物件と比較'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'inspection_list'),
                  builder: (_) => const InspectionListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'inspection_flow'),
                  builder: (_) => InspectionFlowScreen(existing: inspection),
                ),
              ),
              child: const Text('計測をやり直す'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    await InspectionPdf.share([inspection], anchor: shareAnchor(context));
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final ScoreComponent component;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final penalty = component.penalty;
    final color = penalty <= 0
        ? scheme.secondary
        : penalty < 10
        ? scheme.primary
        : scheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  component.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          Text(
            penalty <= 0 ? '±0' : '−${penalty.round()}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
