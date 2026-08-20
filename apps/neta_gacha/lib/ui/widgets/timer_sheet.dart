import 'dart:async';

import 'package:flutter/material.dart';

/// RouletteScreenからモーダルボトムシートとして開くカウントダウンタイマー。
/// 抽選結果の画面を残したまま「◯秒トークしてみよう」に使う。
class TimerSheet extends StatefulWidget {
  const TimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TimerSheet(),
    );
  }

  @override
  State<TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<TimerSheet> {
  static const _defaultSeconds = 60;
  static const _minSeconds = 15;
  static const _maxSeconds = 300;

  int _totalSeconds = _defaultSeconds;
  int _secondsLeft = _defaultSeconds;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _adjust(int delta) {
    if (_running) return;
    setState(() {
      _totalSeconds = (_totalSeconds + delta).clamp(_minSeconds, _maxSeconds);
      _secondsLeft = _totalSeconds;
    });
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() {
          _secondsLeft = 0;
          _running = false;
        });
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _secondsLeft = _totalSeconds;
    });
  }

  String get _formatted {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final finished = !_running && _secondsLeft == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('タイマー', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              finished ? '終了!' : _formatted,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 48,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionChip(
                  label: const Text('-15秒'),
                  onPressed: _running ? null : () => _adjust(-15),
                ),
                const SizedBox(width: 12),
                ActionChip(
                  label: const Text('+15秒'),
                  onPressed: _running ? null : () => _adjust(15),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_running)
                  ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('開始'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('一時停止'),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('リセット'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
