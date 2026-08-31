import 'dart:io';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import 'data/app_scope.dart';
import 'data/ar_noise_map_service.dart';
import 'data/calibration_repository.dart';
import 'data/impulse_probe_service.dart';
import 'data/inspection_repository.dart';
import 'data/sound_meter_service.dart';
import 'firebase_options.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);

  final soundMeter = SoundMeterService();
  final services = AppServices(
    soundMeter: soundMeter,
    impulseProbe: ImpulseProbeService(),
    arNoiseMap: ArNoiseMapService(),
    inspections: InspectionRepository(),
    calibration: CalibrationRepository(soundMeter: soundMeter),
  );
  // 保存データと校正値は起動をブロックせずに読み込む。
  services.inspections.load();
  services.calibration.load();

  runApp(App(services: services));
}

class App extends StatelessWidget {
  const App({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Sound Shield',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // 画面遷移を screen_view として記録する。記録されるのは
        // RouteSettings.name を付けたルートだけなので、画面を追加したら
        // 名前も必ず付けること。
        navigatorObservers: AppInsights.navigatorObservers,
        home: Platform.isIOS
            ? const HomeScreen()
            : const _UnsupportedPlatformScreen(),
      ),
    );
  }
}

/// 計測はSoundAnalysis・ARKitに依存しておりiOS専用。
class _UnsupportedPlatformScreen extends StatelessWidget {
  const _UnsupportedPlatformScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('この機能は iOS 専用です。', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
