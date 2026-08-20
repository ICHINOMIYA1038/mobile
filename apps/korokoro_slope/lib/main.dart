import 'package:flutter/material.dart';

import 'ui/screens/game_screen.dart';

void main() {
  runApp(const KorokoroSlopeApp());
}

class KorokoroSlopeApp extends StatelessWidget {
  const KorokoroSlopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'コロコロスロープ',
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
    );
  }
}
