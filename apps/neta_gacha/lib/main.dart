import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetaGachaApp());
}

class NetaGachaApp extends StatelessWidget {
  const NetaGachaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '配信ネタガチャ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
