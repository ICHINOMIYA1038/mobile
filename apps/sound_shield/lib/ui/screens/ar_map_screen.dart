import 'dart:async';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_scope.dart';
import '../../data/ar_noise_map_service.dart';
import '../../logic/ar_map_analyzer.dart';
import '../../models/ar_noise_sample.dart';
import '../../models/countermeasure.dart';
import '../../models/measurement_result.dart';
import 'measuring_screen.dart';
import 'simulator_screen.dart';

/// 音の侵入マップ(AR)。カメラ映像の上に、記録した位置のレベルを色付きの球で置く。
/// ユーザーは「窓」「壁」などのチップで今かざしている面を選びながら端末を動かす。
class ArMapScreen extends StatefulWidget {
  const ArMapScreen({super.key});

  @override
  State<ArMapScreen> createState() => _ArMapScreenState();
}

class _ArMapScreenState extends State<ArMapScreen>
    with WidgetsBindingObserver {
  late final ArNoiseMapService _arService;
  StreamSubscription<ArLiveUpdate>? _sub;
  ArLiveUpdate? _live;
  ArSurface _surface = ArSurface.center;
  bool _running = false;
  bool _checked = false;
  bool _supported = true;
  bool _allowed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _arService = AppScope.of(context).arNoiseMap;
      _prepare();
    });
  }

  /// バックグラウンドへ行ったら計測は続けられない(ARもマイクも止まる)ので終了する。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _running) {
      _abort('バックグラウンドに移動したため計測を終了しました');
    }
  }

  Future<void> _abort(String message) async {
    await _sub?.cancel();
    _sub = null;
    await _arService.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _live = null;
      _error = message;
    });
  }

  Future<void> _prepare() async {
    final services = AppScope.of(context);
    final mic = await services.soundMeter.checkAndRequestPermission();
    final supported = await services.arNoiseMap.isSupported();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _allowed = mic;
      _supported = supported;
    });
  }

  Future<void> _start() async {
    final services = AppScope.of(context);
    setState(() => _error = null);
    try {
      await services.arNoiseMap.setSurface(_surface);
      await services.arNoiseMap.start();
      _sub = services.arNoiseMap.liveStream.listen((u) {
        if (!mounted) return;
        if (u.interrupted) {
          _abort('音声入力が中断されたため計測を終了しました');
          return;
        }
        setState(() => _live = u);
      });
      setState(() => _running = true);
      await AppInsights.logEvent('ar_map_started');
    } on PlatformException catch (e) {
      setState(
        () => _error = e.code == 'camera_denied'
            ? 'カメラの利用が許可されていません。設定アプリの「Sound Shield」でカメラを許可してください。'
            : 'ARを開始できませんでした(${e.code})',
      );
    }
  }

  Future<void> _stop() async {
    final services = AppScope.of(context);
    await _sub?.cancel();
    _sub = null;
    final samples = await services.arNoiseMap.stop();
    if (!mounted) return;
    setState(() => _running = false);
    final analysis = const ArMapAnalyzer().analyze(samples);
    await AppInsights.logEvent(
      'ar_map_finished',
      parameters: {
        'samples': samples.length,
        'hottest': analysis.hottest?.surface?.name ?? 'none',
      },
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ar_map_result'),
        builder: (_) => ArMapResultScreen(analysis: analysis),
      ),
    );
  }

  Future<void> _select(ArSurface surface) async {
    setState(() => _surface = surface);
    if (_running) await AppScope.of(context).arNoiseMap.setSurface(surface);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    if (_running) _arService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_supported || !_allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('音の侵入マップ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              !_supported
                  ? 'この端末はARの位置追跡に対応していません。'
                  : 'マイクの利用が許可されていません。設定アプリから許可してください。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: UiKitView(viewType: ArNoiseMapService.viewType),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () async {
                        // 先にネイティブ側を止める。dispose に任せると UiKitView が
                        // 先に破棄され、エンジンと AR セッションが止まらない。
                        if (_running) {
                          await AppScope.of(context).arNoiseMap.stop();
                          _running = false;
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    const Spacer(),
                    if (_live != null)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_live!.db.round()} dB ・ ${_live!.count}点'
                          '${_live!.trackingNormal ? '' : ' ・ 位置を認識中…'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _running
                        ? '今かざしている面を選びながら、壁・窓に沿ってゆっくり動かしてください'
                        : '部屋の中央で「開始」を押し、壁や窓に沿って端末を動かします',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final s in ArSurface.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s.label),
                            selected: _surface == s,
                            onSelected: (_) => _select(s),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: TextStyle(color: scheme.tertiary)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _running
                      ? FilledButton(
                          onPressed: (_live?.count ?? 0) < 8 ? null : _stop,
                          child: const Text('終了して結果を見る'),
                        )
                      : FilledButton(onPressed: _start, child: const Text('開始')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ARマップの結果。面ごとの平均レベルを横棒で並べ、主な侵入経路を示す。
class ArMapResultScreen extends StatelessWidget {
  const ArMapResultScreen({super.key, required this.analysis});

  final ArMapAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hottest = analysis.hottest;
    final span = (analysis.maxDb - analysis.minDb).clamp(6.0, 60.0);
    return Scaffold(
      appBar: AppBar(title: const Text('侵入マップの結果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (hottest != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主な侵入経路: ${hottest.label}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '平均 ${hottest.meanDb.round()}dB(全体平均 ${analysis.overallMeanDb.round()}dB) ・ '
                      '${hottest.lowShare > 0.5 ? '低音中心(構造・交通)' : '中高音中心(隙間・話し声)'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text('面ごとの平均レベル', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final s in analysis.stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 72, child: Text(s.label)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 14,
                          value: ((s.meanDb - analysis.minDb) / span).clamp(0.05, 1.0),
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: s == hottest ? scheme.tertiary : scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${s.meanDb.round()}dB',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('この経路に効く対策を予測'),
              onPressed: () => _openSimulator(context),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('ホームに戻る'),
            ),
          ],
        ),
      ),
    );
  }

  /// シミュレーターには帯域別の計測結果が要るので、その場で15秒計測してから開く。
  Future<void> _openSimulator(BuildContext context) async {
    final services = AppScope.of(context);
    final routes = analysis.routes;
    final result = await Navigator.of(context).push<MeasurementResult>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ar_map_measure'),
        builder: (_) => MeasuringScreen(
          soundMeterService: services.soundMeter,
          duration: const Duration(seconds: 15),
          returnResult: true,
          title: '対策予測のための計測',
          hint: '${analysis.hottest?.label ?? '弱点'}の近くで15秒計測します',
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'simulator'),
        builder: (_) => SimulatorScreen(
          result: result,
          routes: routes.isEmpty ? const <NoiseRoute>[] : routes,
          contextLabel: '侵入マップ',
        ),
      ),
    );
  }
}
