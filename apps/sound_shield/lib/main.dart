import 'dart:io';

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import 'data/sound_meter_service.dart';
import 'firebase_options.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Shield',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // 画面遷移を screen_view として記録する。記録されるのは
      // RouteSettings.name を付けたルートだけなので、画面を追加したら
      // 名前も必ず付けること。
      navigatorObservers: AppInsights.navigatorObservers,
      home: Platform.isIOS
          ? HomeScreen(soundMeterService: SoundMeterService())
          : const _UnsupportedPlatformScreen(),
    );
  }
}

/// 騒音計測はSNSoundClassifier(Apple SoundAnalysis)に依存しておりiOS専用。
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
