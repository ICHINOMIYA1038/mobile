import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  final state = AppState(ApiClient(AppConfig.apiBase));
  runApp(AppScope(state: state, child: const App()));
  state.init();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F5D62);
    return MaterialApp(
      title: '話して受かる宅建',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F2),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 0),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      // 画面遷移を screen_view として記録する。RouteSettings.name を付けたルートだけが
      // 記録されるので、画面を追加したら名前も必ず付けること。
      navigatorObservers: AppInsights.navigatorObservers,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.me == null) {
      return Scaffold(
        body: Center(
          child: state.error != null
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 40),
                      const SizedBox(height: 12),
                      const Text('サーバーに接続できませんでした。\n通信環境を確認してもう一度お試しください。', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: state.init, child: const Text('再試行')),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final me = state.me!;
    final firstTime = me.examDate == null && me.turnCounts.isEmpty;
    return firstTime ? const OnboardingScreen() : const HomeScreen();
  }
}
