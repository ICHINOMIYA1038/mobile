import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/inspection_repository.dart';
import '../../logic/countermeasure_simulator.dart';
import '../../logic/sound_label_localizer.dart';
import '../../models/countermeasure.dart';
import '../../models/countermeasure_record.dart';
import '../../models/measurement_result.dart';
import 'before_after_screen.dart';

/// 対策シミュレーター。計測結果に各対策を当てはめ、予測ΔdB・費用・
/// 「効かない理由」を並べる。
class SimulatorScreen extends StatelessWidget {
  const SimulatorScreen({
    super.key,
    required this.result,
    this.routes = const [],
    this.contextLabel,
  });

  final MeasurementResult result;
  final List<NoiseRoute> routes;

  /// 「○○マンション 302号室」「侵入マップ」など、どの計測に対する予測か。
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final predictions = const CountermeasureSimulator().predict(
      result,
      routes: routes,
    );
    final effectiveRoutes = routes.isNotEmpty
        ? routes
        : CountermeasureSimulator.inferRoutes(result);
    final topLabel = result.soundLabels.isNotEmpty
        ? describeSoundLabel(result.soundLabels.first.identifier)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('対策シミュレーター')),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '現状 ${(predictions.isEmpty ? result.overallLeqDb : predictions.first.beforeDb).round()}dB'
                        '${contextLabel != null ? ' ・ $contextLabel' : ''}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '推定される侵入経路: ${effectiveRoutes.map((r) => r.label).join('・')}'
                        '${topLabel != null ? ' ・ 主な音: $topLabel' : ''}'
                        ' ・ ${result.lowShare > 0.55 ? '低音中心' : result.highShare > 0.35 ? '高音中心' : '中音中心'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final p in predictions)
                  _PredictionCard(
                    prediction: p,
                    onTry: () => _startRecord(context, p),
                  ),
                const SizedBox(height: 8),
                Text(
                  '減衰量は各対策の「根拠」に示した公表値・実測記事・建築音響の一般値をもとにした目安で、'
                  '施工状態や音の種類で大きく変わります(±数dB)。購入前の判断材料としてお使いください。'
                  '実施後に「対策の効果を検証」で再計測すると、実際の効果を確かめられます。',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _startRecord(
    BuildContext context,
    CountermeasurePrediction p,
  ) async {
    final services = AppScope.of(context);
    final record = CountermeasureRecord(
      id: InspectionRepository.newId(),
      measureId: p.measure.id,
      measureName: p.measure.name,
      createdAt: DateTime.now(),
      before: result,
      predictedDeltaDb: p.deltaDb,
      place: contextLabel ?? '',
    );
    await services.inspections.saveRecord(record);
    await AppInsights.logEvent(
      'countermeasure_planned',
      parameters: {
        'measure': p.measure.id,
        'predicted_delta_db': p.deltaDb.round(),
      },
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${p.measure.name}」を対策の記録に追加しました。実施後に同じ場所で再計測してください。'),
        action: SnackBarAction(
          label: '記録を見る',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'before_after'),
              builder: (_) => const BeforeAfterScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, required this.onTry});

  final CountermeasurePrediction prediction;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = prediction;
    final m = p.measure;
    final color = switch (p.verdict) {
      PredictionVerdict.none => scheme.outline,
      PredictionVerdict.small => scheme.primary,
      PredictionVerdict.medium => scheme.secondary,
      PredictionVerdict.large => scheme.secondary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    m.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.deltaDb < 1 ? '−0dB' : '−${p.deltaDb.toStringAsFixed(p.deltaDb < 10 ? 1 : 0)}dB',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '${p.beforeDb.round()}→${p.afterDb.round()}dB',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Tag(text: p.verdict.label, color: color),
                _Tag(text: m.costLabel, color: scheme.outline),
                _Tag(text: m.diy ? '自分で設置' : '工事', color: scheme.outline),
                if (!p.matchesRoute)
                  _Tag(text: '経路が違う', color: scheme.tertiary),
              ],
            ),
            const SizedBox(height: 8),
            Text(m.summary, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              p.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '根拠: ${m.evidence}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
            if (m.caveat != null) ...[
              const SizedBox(height: 4),
              Text(
                '注意: ${m.caveat}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 8),
            _BandDeltaStrip(before: p.beforeBands, after: p.afterBands),
            if (p.verdict != PredictionVerdict.none) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTry,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('この対策を試す(前後で検証)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 帯域ごとの before/after を小さな縦棒で並べる。
class _BandDeltaStrip extends StatelessWidget {
  const _BandDeltaStrip({required this.before, required this.after});

  final List<double> before;
  final List<double> after;

  static const _labels = ['31', '63', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (before.isEmpty) return const SizedBox.shrink();
    const floor = 20.0;
    const ceil = 90.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              for (var i = 0; i < before.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          heightFactor: ((before[i] - floor) / (ceil - floor)).clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.outline.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          heightFactor: ((after[i] - floor) / (ceil - floor)).clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            for (final l in _labels.take(before.length))
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: scheme.outline),
                ),
              ),
          ],
        ),
        Text(
          'グレー=現状 ・ 色=対策後(帯域別, Hz)',
          style: TextStyle(fontSize: 10, color: scheme.outline),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
