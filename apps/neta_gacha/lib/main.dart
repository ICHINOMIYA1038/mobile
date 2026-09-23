import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 抽選画面は固定高さのColumnで横向きだと収まらない。縦固定で十分なアプリ。
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // リマインダーは毎日繰り返す1件の予約だが、OSの都合で消えることがあるため
  // 起動のたびに予約し直す(設定画面を開かない人でも止まらないように)。
  unawaited(NotificationService().rescheduleIfEnabled());
  runApp(const NetaGachaApp());
}

class NetaGachaApp extends StatelessWidget {
  const NetaGachaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ネタガチャ',
      debugShowCheckedModeBanner: false,
      // 時刻ピッカー等の標準ウィジェットを日本語にする。
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
