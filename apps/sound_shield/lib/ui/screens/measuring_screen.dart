import 'dart:async';
import 'dart:math' as math;

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
    this.returnResult = false,
    this.title,
    this.hint,
    this.autoStop = false,
  });

  final SoundMeterService soundMeterService;

  /// nullなら「止めるまで測定」する時間無指定モード。
  final Duration? duration;

  /// true なら結果画面へ遷移せず、計測結果を `Navigator.pop` の戻り値として返す
  /// (内見モード・Before/After など、呼び出し側が結果を使う場合)。
  final bool returnResult;

  /// 計測中画面の見出し(内見モードのステップ名など)。
  final String? title;

  /// 見出し下に出す補足(「窓から30cmの位置で」など)。
  final String? hint;

  /// true なら「止めるまで測定」モードで開始し、値が安定したら自動で終える。
  /// [duration] は無視される。静かな環境なら [autoStopMinSeconds] 秒程度で終わり、
  /// 変動が大きくても [autoStopMaxSeconds] 秒で打ち切る。
  final bool autoStop;

  static const autoStopMinSeconds = 6;
  static const autoStopMaxSeconds = 15;

  /// 直近3秒で累積Leqの動きがこの幅(dB)に収まったら「安定」とみなす。
  static const autoStopStableDb = 0.4;

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

  bool get _isOpenEnded => widget.duration == null && !widget.autoStop;

  /// 自動終了モード用: 200msごとのライブ値からの累積パワー平均(簡易Leq)。
  double _livePowerSum = 0;
  int _liveCount = 0;
  final List<double> _leqHistory = [];
  bool _stable = false;

  @override
  void initState() {
    super.initState();
    _liveDbSubscription = widget.soundMeterService.liveDbStream.listen((db) {
      if (!mounted) return;
      setState(() => _currentDb = db);
      if (widget.autoStop) _trackAutoStop(db);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (widget.autoStop) {
          _elapsed += const Duration(seconds: 1);
          if (_elapsed.inSeconds >= MeasuringScreen.autoStopMaxSeconds) {
            _endOpenEndedMeasurement();
          }
        } else if (_isOpenEnded) {
          _elapsed += const Duration(seconds: 1);
        } else {
          final nextSeconds = _remaining.inSeconds - 1;
          _remaining = Duration(seconds: nextSeconds < 0 ? 0 : nextSeconds);
        }
      });
    });
    unawaited(_runMeasurement());
  }

  /// 累積Leqが3秒間動かなくなったら finishMeasurement で確定する。
  void _trackAutoStop(double db) {
    _livePowerSum += math.pow(10, db / 10).toDouble();
    _liveCount++;
    final leq = 10 * math.log(_livePowerSum / _liveCount) / math.ln10;
    _leqHistory.add(leq);
    // ライブ値は約200ms間隔 → 3秒 ≒ 15サンプル。
    const window = 15;
    const minCount = MeasuringScreen.autoStopMinSeconds * 5;
    if (_liveCount < minCount || _leqHistory.length <= window) return;
    final past = _leqHistory[_leqHistory.length - 1 - window];
    if ((leq - past).abs() <= MeasuringScreen.autoStopStableDb) {
      _stable = true;
      _endOpenEndedMeasurement();
    }
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
        widget.autoStop ? null : widget.duration,
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
        if (widget.returnResult) {
          Navigator.of(context).pop(result);
          return;
        }
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
      appBar: AppBar(title: Text(widget.title ?? '計測中')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.hint != null) ...[
                Text(
                  widget.hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                widget.autoStop
                    ? (_stable
                          ? '安定しました'
                          : '経過 ${_formatElapsed(_elapsed)} ・ 安定したら自動終了'
                                '(最長${MeasuringScreen.autoStopMaxSeconds}秒)')
                    : _isOpenEnded
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
              if (widget.autoStop)
                OutlinedButton(
                  onPressed: _isEnding ? null : _cancel,
                  child: const Text('キャンセル'),
                )
              else if (_isOpenEnded) ...[
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
