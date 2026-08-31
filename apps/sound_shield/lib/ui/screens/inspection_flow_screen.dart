import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_scope.dart';
import '../../data/impulse_probe_service.dart';
import '../../data/inspection_repository.dart';
import '../../models/impulse_result.dart';
import '../../models/inspection.dart';
import '../../models/measurement_result.dart';
import 'inspection_result_screen.dart';
import 'measuring_screen.dart';

/// 内見診断のウィザード。名前を付けて、5つのステップを順に計測する。
/// 各ステップはスキップ可能(採点では未計測として扱う)。
class InspectionFlowScreen extends StatefulWidget {
  const InspectionFlowScreen({super.key, this.existing});

  /// 既存の診断をやり直す場合。
  final Inspection? existing;

  @override
  State<InspectionFlowScreen> createState() => _InspectionFlowScreenState();
}

class _InspectionFlowScreenState extends State<InspectionFlowScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Inspection _inspection =
      widget.existing ??
      Inspection(
        id: InspectionRepository.newId(),
        name: '',
        createdAt: DateTime.now(),
      );
  int _stepIndex = -1; // -1: 名前入力
  bool _busy = false;
  String? _impulseHint;

  InspectionStep get _step => InspectionStep.values[_stepIndex];
  late final ImpulseProbeService _probe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _probe = AppScope.of(context).impulseProbe;
    });
  }

  @override
  void dispose() {
    // 待機中に画面を離れたらネイティブ側の待機も止める。
    if (_busy) _probe.cancel();
    _name.dispose();
    super.dispose();
  }

  /// 計測途中で戻ろうとしたら確認する(データが1つでもあれば)。
  Future<bool> _confirmLeave() async {
    if (_stepIndex < 0 || !_inspection.hasAnyData) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('診断を中断しますか?'),
        content: const Text('ここまでの計測は保存されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('中断する'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _begin() async {
    final services = AppScope.of(context);
    final name = _name.text.trim().isEmpty
        ? '物件 ${services.inspections.inspections.length + 1}'
        : _name.text.trim();
    setState(() {
      _inspection = _inspection.copyWith(name: name);
      _stepIndex = 0;
    });
    await AppInsights.logEvent('inspection_started');
  }

  Future<void> _runCurrentStep() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_step.isImpulse) {
        await _runImpulse();
      } else {
        await _runMeasurement();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runMeasurement() async {
    final services = AppScope.of(context);
    final result = await Navigator.of(context).push<MeasurementResult>(
      MaterialPageRoute(
        settings: RouteSettings(name: 'inspection_${_step.name}'),
        builder: (_) => MeasuringScreen(
          soundMeterService: services.soundMeter,
          duration: null,
          autoStop: true,
          returnResult: true,
          title: _step.title,
          hint: _step.instruction,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _inspection = switch (_step) {
        InspectionStep.ambient => _inspection.copyWith(ambient: result),
        InspectionStep.window => _inspection.copyWith(window: result),
        InspectionStep.neighbor => _inspection.copyWith(neighbor: result),
        _ => _inspection,
      };
    });
    _advance();
  }

  Future<void> _runImpulse() async {
    final services = AppScope.of(context);
    setState(
      () => _impulseHint = _step == InspectionStep.knock
          ? '静かにして、壁を1回叩いてください…'
          : '静かにして、手を1回叩いてください…',
    );
    try {
      final result = await services.impulseProbe.capture();
      if (!mounted) return;
      setState(() {
        _impulseHint = null;
        _inspection = _step == InspectionStep.knock
            ? _inspection.copyWith(knock: result)
            : _inspection.copyWith(clap: result);
      });
      _showImpulseFeedback(result);
      _advance();
    } on NoImpulseException {
      if (!mounted) return;
      setState(() => _impulseHint = '音が検出できませんでした。もう少し強めに叩いてください。');
    } on ImpulseCancelledException {
      if (mounted) setState(() => _impulseHint = null);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(
        () => _impulseHint = switch (e.code) {
          'interrupted' => '着信などで中断されました。もう一度お試しください。',
          'analysis_failed' => '解析できませんでした。もう一度叩いてください。',
          'busy' => '前の待機が終わっていません。少し待ってからお試しください。',
          _ => '計測を開始できませんでした(${e.code})。',
        },
      );
    }
  }

  void _showImpulseFeedback(ImpulseResult result) {
    final text = _step == InspectionStep.knock
        ? 'ノック音を捕捉(重心 ${result.spectralCentroidHz.round()}Hz)'
        : '手叩きを捕捉(残響 ${result.rt60?.toStringAsFixed(2) ?? '--'}秒)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _skip() {
    _advance();
  }

  Future<void> _advance() async {
    if (_stepIndex + 1 < InspectionStep.values.length) {
      setState(() => _stepIndex++);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final services = AppScope.of(context);
    if (!_inspection.hasAnyData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのステップを飛ばしたため、診断は保存しませんでした。')),
      );
      Navigator.of(context).pop();
      return;
    }
    await services.inspections.saveInspection(_inspection);
    await AppInsights.logEvent(
      'inspection_finished',
      parameters: {
        'steps': [
          if (_inspection.ambient != null) 'ambient',
          if (_inspection.window != null) 'window',
          if (_inspection.knock != null) 'knock',
          if (_inspection.clap != null) 'clap',
          if (_inspection.neighbor != null) 'neighbor',
        ].length,
      },
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'inspection_result'),
        builder: (_) => InspectionResultScreen(inspection: _inspection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_stepIndex < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('内見診断')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '診断の名前(任意)',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: '空欄なら「物件 1」のように自動で付きます',
                    helperText:
                        '比較のときに見分けるためのメモです。物件名でなくても構いません(例: A, 駅近, 3階南)。端末内にのみ保存され、送信されません。',
                    helperMaxLines: 3,
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _begin(),
                ),
                const SizedBox(height: 24),
                Text('流れ(約3分)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final (i, step) in InspectionStep.values.indexed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurface),
                      ),
                    ),
                    title: Text(step.title),
                    subtitle: Text(step.instruction),
                  ),
                const Spacer(),
                Text(
                  '計測値は同じ端末での相対的な目安です。窓・ドアを閉め、テレビや会話を止めてから始めてください。',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _begin, child: const Text('診断を始める')),
              ],
            ),
          ),
        ),
      );
    }

    final step = _step;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!leave || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${_stepIndex + 1} / ${InspectionStep.values.length}  ${step.title}',
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_stepIndex + 1) / InspectionStep.values.length,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 32),
                Icon(
                  switch (step) {
                    InspectionStep.ambient => Icons.hearing_outlined,
                    InspectionStep.window => Icons.window_outlined,
                    InspectionStep.knock => Icons.back_hand_outlined,
                    InspectionStep.clap => Icons.sign_language_outlined,
                    InspectionStep.neighbor => Icons.meeting_room_outlined,
                  },
                  size: 64,
                  color: scheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  step.instruction,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  step.isImpulse
                      ? '「待機して叩く」を押し、1秒ほど待ってから1回だけ叩いてください。'
                      : '「計測」を押すと計測します。値が安定すれば6秒ほどで自動的に終わります。',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
                if (_impulseHint != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _impulseHint!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _runCurrentStep,
                  child: Text(step.isImpulse ? '待機して叩く' : '計測を開始'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? _probe.cancel : _skip,
                  child: Text(_busy ? 'キャンセル' : 'このステップを飛ばす'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
