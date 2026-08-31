import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../models/countermeasure_record.dart';
import '../../models/measurement_result.dart';
import 'measuring_screen.dart';
import 'meter_screen.dart';

/// 対策の Before/After 記録。対策前の計測に対して、実施後に再計測して
/// 実際に何dB下がったかを確かめる。
class BeforeAfterScreen extends StatelessWidget {
  const BeforeAfterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('対策の効果を検証')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.inspections,
          builder: (context, _) {
            final records = services.inspections.records;
            if (records.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 48, color: scheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        '記録がまだありません。\n騒音計で計測 → 対策シミュレーターで「この対策を試す」を押すと、ここに対策前の計測が保存されます。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.outline),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'meter'),
                            builder: (_) => const MeterScreen(),
                          ),
                        ),
                        child: const Text('騒音計で計測する'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final r in records)
                  _RecordCard(
                    record: r,
                    onMeasureAfter: () => _measureAfter(context, r),
                    onDelete: () => services.inspections.deleteRecord(r.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _measureAfter(BuildContext context, CountermeasureRecord r) async {
    final services = AppScope.of(context);
    final granted = await services.soundMeter.checkAndRequestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マイクの利用が許可されていません。')),
      );
      return;
    }
    final after = await Navigator.of(context).push<MeasurementResult>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'after_measure'),
        builder: (_) => MeasuringScreen(
          soundMeterService: services.soundMeter,
          duration: Duration(seconds: r.before.durationSeconds.clamp(10, 60)),
          returnResult: true,
          title: '対策後の計測',
          hint: '対策前と同じ場所・同じ時間帯・同じ向きで計測してください',
        ),
      ),
    );
    if (after == null) return;
    final updated = r.copyWith(after: after);
    await services.inspections.saveRecord(updated);
    // 匿名の効果データ(対策の種類と帯域別ΔdBのみ)。予測モデルの補正に使う。
    final bandDeltas = <String, Object>{};
    for (var i = 0; i < r.before.bands.length && i < after.bands.length; i++) {
      bandDeltas['band_${r.before.bands[i].centerHz.round()}'] =
          (r.before.bands[i].leqDb - after.bands[i].leqDb).round();
    }
    await AppInsights.logEvent(
      'countermeasure_verified',
      parameters: {
        'measure': r.measureId,
        'predicted_delta_db': r.predictedDeltaDb?.round() ?? 0,
        'actual_delta_db': (updated.actualDeltaDb ?? 0).round(),
        ...bandDeltas,
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.onMeasureAfter,
    required this.onDelete,
  });

  final CountermeasureRecord record;
  final VoidCallback onMeasureAfter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actual = record.actualDeltaDb;
    final predicted = record.predictedDeltaDb;
    final date = record.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.measureName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            Text(
              '${date.year}/${date.month}/${date.day}'
              '${record.place.isNotEmpty ? ' ・ ${record.place}' : ''}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: '対策前', value: '${record.before.overallLeqDb.round()}dB'),
                Icon(Icons.arrow_forward, color: scheme.outline),
                _Stat(
                  label: '対策後',
                  value: record.after == null
                      ? '—'
                      : '${record.after!.overallLeqDb.round()}dB',
                ),
                const Spacer(),
                if (actual != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${actual >= 0 ? '−' : '+'}${actual.abs().toStringAsFixed(1)}dB',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: actual >= 1 ? scheme.secondary : scheme.tertiary,
                        ),
                      ),
                      if (predicted != null)
                        Text(
                          '予測 −${predicted.toStringAsFixed(1)}dB',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.outline),
                        ),
                    ],
                  ),
              ],
            ),
            if (record.after == null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onMeasureAfter,
                child: const Text('対策後を計測する'),
              ),
            ] else if (actual != null && predicted != null) ...[
              const SizedBox(height: 8),
              Text(
                actual >= predicted - 1
                    ? '予測どおり、またはそれ以上の効果でした。'
                    : actual >= 1
                    ? '予測より効果は小さめでした。隙間や設置状態を見直すと改善することがあります。'
                    : '効果が確認できませんでした。侵入経路が別の場所か、対策が音の種類に合っていない可能性があります。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
