import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sound_meter_service.dart';
import '../widgets/level_gauge.dart';
import 'result_screen.dart';

class MeasuringScreen extends StatefulWidget {
  const MeasuringScreen({
    super.key,
    required this.soundMeterService,
    required this.duration,
  });

  final SoundMeterService soundMeterService;

  /// nullなら「止めるまで測定」する時間無指定モード。
  final Duration? duration;

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

class _MeasuringScreenState extends State<MeasuringScreen> {
  StreamSubscription<double>? _liveDbSubscription;
  Timer? _tickTimer;
  double _currentDb = 0;
  late Duration _remaining = widget.duration ?? Duration.zero;
  Duration _elapsed = Duration.zero;
  bool _isFinishing = false;
  bool _isEnding = false;

  bool get _isOpenEnded => widget.duration == null;

  @override
  void initState() {
    super.initState();
    _liveDbSubscription = widget.soundMeterService.liveDbStream.listen((db) {
      if (!mounted) return;
      setState(() => _currentDb = db);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isOpenEnded) {
          _elapsed += const Duration(seconds: 1);
        } else {
          final nextSeconds = _remaining.inSeconds - 1;
          _remaining = Duration(seconds: nextSeconds < 0 ? 0 : nextSeconds);
        }
      });
    });
    unawaited(_runMeasurement());
  }

  Future<void> _runMeasurement() async {
    await AppInsights.logEvent(
      'measurement_started',
      parameters: {
        'duration_seconds': widget.duration?.inSeconds ?? 0,
        'open_ended': _isOpenEnded ? 1 : 0,
      },
    );
    try {
      final result = await widget.soundMeterService.startMeasurement(
        widget.duration,
      );
      await AppInsights.logEvent(
        'measurement_finished',
        parameters: {
          'duration_seconds': result.durationSeconds,
          'open_ended': _isOpenEnded ? 1 : 0,
          'overall_leq_db': result.overallLeqDb.round(),
          'top_sound_label': result.soundLabels.isNotEmpty
              ? result.soundLabels.first.identifier
              : 'none',
        },
      );
      _finish(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'result'),
            builder: (_) => ResultScreen(result: result),
          ),
        );
      });
    } on MeasurementCancelledException {
      _finish(() => Navigator.of(context).pop());
    } on PlatformException catch (e) {
      final message = _messageForError(e);
      _finish(() {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  String _messageForError(PlatformException e) {
    switch (e.code) {
      case 'permission_denied':
        return 'マイクの利用が許可されていません。';
      case 'non_built_in_mic':
        return '内蔵マイク以外が接続されているため計測できません。イヤホン等を外してください。';
      case 'already_measuring':
        return '既に計測中です。';
      default:
        return '計測を開始できませんでした。';
    }
  }

  void _finish(VoidCallback navigate) {
    if (_isFinishing || !mounted) return;
    _isFinishing = true;
    _liveDbSubscription?.cancel();
    _tickTimer?.cancel();
    navigate();
  }

  @override
  void dispose() {
    _liveDbSubscription?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    await widget.soundMeterService.cancelMeasurement();
  }

  /// 「止めるまで測定」モードで、ここまでの結果を保持したまま計測を終える。
  Future<void> _endOpenEndedMeasurement() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    await widget.soundMeterService.finishMeasurement();
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 目安値のレンジ(概ね30〜100dB)を0.0〜1.0に正規化してゲージに反映する。
    final level = ((_currentDb - 30) / 70).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('計測中')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isOpenEnded
                    ? '経過 ${_formatElapsed(_elapsed)}'
                    : '残り ${_remaining.inSeconds.toString().padLeft(2, '0')}秒',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  LevelGauge(level: level),
                  // 針とハブが円の中心にあるため、読み取り値はそこと重ならないよう
                  // ダイヤル上部の空きスペースに寄せて表示する。
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentDb.round().toString(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'dB ・ 目安値',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              if (_isOpenEnded) ...[
                FilledButton(
                  onPressed: _isEnding ? null : _endOpenEndedMeasurement,
                  child: const Text('計測終了'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isEnding ? null : _cancel,
                  child: const Text('破棄してやり直す'),
                ),
              ] else
                OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('キャンセル'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
