import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../widgets/level_gauge.dart';
import 'measuring_screen.dart';

enum _StartMode { fixed, openEnded }

/// 騒音計(v1のホーム画面)。計測方法と時間を選んで計測を始める。
class MeterScreen extends StatefulWidget {
  const MeterScreen({super.key});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> {
  static const _durationOptions = [10, 15, 30, 60];

  _StartMode _mode = _StartMode.fixed;
  int _selectedDuration = 15;
  bool _isRequestingPermission = false;

  Future<void> _startMeasurement() async {
    final soundMeter = AppScope.of(context).soundMeter;
    setState(() => _isRequestingPermission = true);
    final granted = await soundMeter.checkAndRequestPermission();
    if (!mounted) return;
    setState(() => _isRequestingPermission = false);

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('マイクの利用が許可されていません。設定アプリからマイクへのアクセスを許可してください。'),
        ),
      );
      return;
    }

    final duration = _mode == _StartMode.fixed
        ? Duration(seconds: _selectedDuration)
        : null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'measuring'),
        builder: (_) =>
            MeasuringScreen(soundMeterService: soundMeter, duration: duration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('騒音計')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  const LevelGauge(level: 0),
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '‑‑',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'dB ・ 待機中',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '周囲の騒音を計測して、対策の効果を予測します',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 28),
              Text(
                '計測方法',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              SegmentedSelector<_StartMode>(
                options: const [_StartMode.fixed, _StartMode.openEnded],
                labelOf: (mode) =>
                    mode == _StartMode.fixed ? '時間を指定' : '止めるまで測定',
                selected: _mode,
                onSelected: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 16),
              if (_mode == _StartMode.fixed) ...[
                Text(
                  '計測時間',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 8),
                SegmentedSelector<int>(
                  options: _durationOptions,
                  labelOf: (seconds) => '$seconds秒',
                  selected: _selectedDuration,
                  onSelected: (seconds) =>
                      setState(() => _selectedDuration = seconds),
                ),
              ] else
                Text(
                  '計測中の画面で「計測終了」を押すまで測り続けます',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _isRequestingPermission ? null : _startMeasurement,
                child: _isRequestingPermission
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('計測を開始'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 選択肢を横並びのピルで見せる汎用セグメントコントロール。
class SegmentedSelector<T> extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: option == selected ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labelOf(option),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: option == selected
                          ? scheme.onPrimary
                          : scheme.outline,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
