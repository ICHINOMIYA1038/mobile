import 'package:flutter/material.dart';

import '../../logic/noise_level.dart';
import '../widgets/noise_scale_chart.dart';

/// 「静か/普通/うるさい」の3区分がどんな音量を指すのかを、実例つきの
/// スケール図で説明する画面。結果画面の状態バッジから遷移する。
class NoiseScaleScreen extends StatelessWidget {
  const NoiseScaleScreen({super.key, this.measuredDb});

  /// 呼び出し元の計測値。指定するとスケール上に位置を重ねて表示する。
  final double? measuredDb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('騒音レベルの目安')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'この基準について',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '環境省「騒音に係る環境基準」と、暮らしの中の音量目安表をもとに'
              '3段階に分けています。昼夜は区別しない簡易な目安です。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 20),
            _LegendRow(
              color: scheme.secondary,
              title: '静かな環境',
              range: '〜${quietThresholdDb.round()}dB',
              description: '夜間の住宅地程度。ストレスなく過ごせる音量。',
            ),
            _LegendRow(
              color: scheme.primary,
              title: '普通の生活音',
              range: '${quietThresholdDb.round()}〜${loudThresholdDb.round()}dB',
              description: '昼間の住宅地〜銀行窓口や書店程度の、暮らしの中でよくある音。',
            ),
            _LegendRow(
              color: scheme.tertiary,
              title: 'うるさい環境',
              range: '${loudThresholdDb.round()}dB〜',
              description: 'このあたりから対策を検討することをおすすめします。',
            ),
            const SizedBox(height: 24),
            Center(child: NoiseScaleChart(measuredDb: measuredDb)),
            const SizedBox(height: 24),
            Text(
              '出典',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 6),
            Text(
              '・環境省「騒音に係る環境基準について」\n'
              '・一般的な騒音レベル目安表(暮らしの中の音の目安)\n\n'
              '本アプリの計測値はキャリブレーション未実施の相対値のため、'
              '上記の基準値・目安と厳密には一致しません。あくまで目安としてご利用ください。',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.title,
    required this.range,
    required this.description,
  });

  final Color color;
  final String title;
  final String range;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      range,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(
                            color: scheme.outline,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
