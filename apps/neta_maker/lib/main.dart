import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_colors.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetaMakerApp());
}

class NetaMakerApp extends StatelessWidget {
  const NetaMakerApp({super.key});

  static ThemeData _themeFor(AppColors colors, Brightness brightness) {
    const seed = Color(0xFF7A2434);
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      extensions: [colors],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ネタメーカー',
      debugShowCheckedModeBanner: false,
      // 「魔女の羊皮紙・アンティーク占い師の手帳」という世界観を常に保つため、
      // システム設定に関わらずパーチメント(明るい紙色)テーマ固定にしている。
      themeMode: ThemeMode.light,
      theme: _themeFor(AppColors.light, Brightness.light),
      darkTheme: _themeFor(AppColors.light, Brightness.light),
      // 大きな文字設定でもレイアウトが壊れないよう、上限を設ける。
      // (視認性バグ対策の一環。neko_chemistry と同じ方針)
      builder: (context, child) {
        final clampedScaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
