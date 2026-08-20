import 'package:flutter/material.dart';

import '../screens/accessory_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/home_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';

/// ホーム・進捗・きせかえ・用語集・設定を切り替える、常時表示のフッターナビゲーション。
/// クイズ画面・結果画面はここに乗せず、Navigator.pushで独立した画面として開くため、
/// 集中して取り組んでいる間はフッターごと画面から隠れる。
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  /// タブを切り替えるたびに新しいインスタンスを作る。以前ドロワーの
  /// pushReplacementでも各画面が作り直されていたのと同じ挙動(=別タブで
  /// 進捗が変わっても、戻ってきたときに最新の状態を読み直す)を保つため。
  List<Widget> get _screens => [
    const HomeScreen(),
    ProgressScreen(),
    AccessoryScreen(),
    const GlossaryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        indicatorColor: nekoOrange.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '進捗',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'きせかえ',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '用語集',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
