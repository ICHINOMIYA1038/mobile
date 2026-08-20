import 'package:flutter/material.dart';

import '../../logic/noise_level.dart';
import '../../logic/suggestion_engine.dart';
import '../../models/measurement_result.dart';
import '../../models/suggestion.dart';
import '../widgets/frequency_range_chart.dart';
import '../widgets/sound_overlay_strip.dart';
import '../widgets/time_series_chart.dart';
import 'noise_scale_screen.dart';
import 'suggestions_screen.dart';

/// 計測データ(数値+2つのグラフ)専用の画面。対策の提案は別画面([SuggestionsScreen])に分離し、
/// 「何が起きたか」→「どうすればいいか」の2段階で読めるようにしている。
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final MeasurementResult result;

  @override
  Widget build(BuildContext context) {
    final suggestions = const SuggestionEngine().suggest(result);

    return Scaffold(
      appBar: AppBar(title: const Text('計測結果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Hero(result: result),
            const SizedBox(height: 24),
            Text(
              '周波数帯域別レベル',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'バー=最小〜最大 ・ 太線=平均',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            FrequencyRangeChart(bands: result.bands),
            const SizedBox(height: 24),
            Text(
              '時間経過ごとのレベル',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '検出音を帯で重ね合わせ表示',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            TimeSeriesChart(
              series: result.timeSeries,
              durationSeconds: result.durationSeconds,
            ),
            const SizedBox(height: 4),
            SoundOverlayStrip(
              segments: result.soundTimeline,
              durationSeconds: result.durationSeconds,
            ),
            const SizedBox(height: 24),
            if (suggestions.isEmpty)
              const _NoActionNeededPanel()
            else
              _SuggestionsCta(result: result, suggestions: suggestions),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});

  final MeasurementResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _NoiseStatus.forDb(result.overallLeqDb);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              result.overallLeqDb.round().toString(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 3),
              child: Text(
                'dB',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'noise_scale'),
                  builder: (_) =>
                      NoiseScaleScreen(measuredDb: result.overallLeqDb),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: status.color(scheme).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: status.color(scheme),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: status.color(scheme),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.info_outline,
                    size: 13,
                    color: status.color(scheme),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Stat(label: '最小', value: result.overallMinDb),
            _Stat(label: '平均', value: result.overallLeqDb),
            _Stat(label: 'ピーク', value: result.overallPeakDb),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${result.durationSeconds}秒間の目安値・キャリブレーション未実施',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.round().toString(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 特筆すべき騒音が検出されなかった場合に、提案の代わりに表示する。
class _NoActionNeededPanel extends StatelessWidget {
  const _NoActionNeededPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '静かな環境でした',
                  style: TextStyle(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  '目立った騒音は検出されなかったため、特に対策の必要はありません。',
                  style: TextStyle(
                    color: scheme.secondary.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsCta extends StatelessWidget {
  const _SuggestionsCta({required this.result, required this.suggestions});

  final MeasurementResult result;
  final List<Suggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'suggestions'),
              builder: (_) => SuggestionsScreen(result: result),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '対策を見る',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      '検出音から${suggestions.length}件の提案',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NoiseStatus {
  quiet('静かな環境'),
  moderate('普通の生活音'),
  loud('うるさい環境');

  const _NoiseStatus(this.label);

  final String label;

  static _NoiseStatus forDb(double db) => switch (noiseLevelForDb(db)) {
    NoiseLevel.quiet => _NoiseStatus.quiet,
    NoiseLevel.moderate => _NoiseStatus.moderate,
    NoiseLevel.loud => _NoiseStatus.loud,
  };

  Color color(ColorScheme scheme) => switch (this) {
    _NoiseStatus.quiet => scheme.secondary,
    _NoiseStatus.moderate => scheme.primary,
    _NoiseStatus.loud => scheme.tertiary,
  };
}
