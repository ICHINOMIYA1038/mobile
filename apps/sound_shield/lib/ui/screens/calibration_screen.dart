import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../models/measurement_result.dart';
import 'measuring_screen.dart';

/// 騒音計の校正。手持ちの騒音計と並べて同じ音を測り、差分を保存する。
///
/// 差分で評価する機能(内見診断・ARマップ・Before/After)は校正の影響を受けない。
/// 影響するのは騒音計の表示と「静か/普通/うるさい」の3段階判定のみ。
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  MeasurementResult? _measured;
  final TextEditingController _reference = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _measure() async {
    final services = AppScope.of(context);
    final granted = await services.soundMeter.checkAndRequestPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マイクの利用が許可されていません。')),
      );
      return;
    }
    final result = await Navigator.of(context).push<MeasurementResult>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'calibration_measure'),
        builder: (_) => MeasuringScreen(
          soundMeterService: services.soundMeter,
          duration: const Duration(seconds: 15),
          returnResult: true,
          title: '校正用の計測',
          hint: '基準の騒音計と並べて置き、換気扇やテレビの砂嵐音など「一定の音」を15秒測ります',
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _measured = result);
  }

  Future<void> _apply() async {
    final services = AppScope.of(context);
    final measured = _measured;
    final ref = double.tryParse(_reference.text.trim());
    if (measured == null || ref == null) return;
    // このアプリの表示は既にいまの校正込みなので、差分をそのまま現在値に足す。
    final delta = ref - measured.overallLeqDb;
    final next = services.calibration.adjustmentDb + delta;
    await services.calibration.setAdjustment(next);
    await AppInsights.logEvent(
      'calibration_applied',
      parameters: {'delta_db': delta.round()},
    );
    if (!mounted) return;
    setState(() {
      _measured = null;
      _reference.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('校正しました(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}dB)。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('騒音計の校正')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: services.calibration,
          builder: (context, _) {
            final adj = services.calibration.adjustmentDb;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'iPhoneのマイクは機種ごとの差が小さいため、既定値でもおおよその目安になります。'
                  '手持ちの騒音計に合わせたい場合は、同じ音を両方で測って差を保存してください。'
                  'この校正が影響するのは騒音計の表示と3段階判定だけで、'
                  '内見診断・侵入マップ・対策の検証(いずれも同じ端末内の差分で評価)には影響しません。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '現在の校正値',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: scheme.outline),
                              ),
                              Text(
                                '${adj >= 0 ? '+' : ''}${adj.toStringAsFixed(1)} dB',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '-0.5dB',
                          onPressed: () =>
                              services.calibration.setAdjustment(adj - 0.5),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: '+0.5dB',
                          onPressed: () =>
                              services.calibration.setAdjustment(adj + 0.5),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        TextButton(
                          onPressed: adj == 0
                              ? null
                              : () => services.calibration.reset(),
                          child: const Text('リセット'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('基準の騒音計と合わせる', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '1. 基準の騒音計とこのiPhoneを並べて置く\n'
                  '2. 換気扇・テレビの砂嵐音など「一定の音」を出す(50〜70dBくらいが目安)\n'
                  '3. 下のボタンで15秒計測し、同じ間の騒音計の平均値を入力する',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _measure,
                  icon: const Icon(Icons.mic_none),
                  label: Text(
                    _measured == null
                        ? 'このアプリで15秒計測する'
                        : 'アプリの計測値: ${_measured!.overallLeqDb.toStringAsFixed(1)} dB(再計測)',
                  ),
                ),
                if (_measured != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reference,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '基準の騒音計の平均値(dB)',
                      hintText: '例: 58.5',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: double.tryParse(_reference.text.trim()) == null
                        ? null
                        : _apply,
                    child: const Text('この差で校正する'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
