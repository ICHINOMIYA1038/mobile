import 'package:flutter/material.dart';

import '../screens/glossary_screen.dart';
import '../screens/home_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';

/// ドロワー(モバイルメニュー)からいけるハブ画面。
enum AppScreen { home, progress, glossary, settings }

/// ホーム・進捗・用語集・設定の各ハブ画面で共有するモバイルメニュー。
/// クイズ画面・結果画面は集中して取り組んでほしいため、あえて付けていない。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentScreen});

  final AppScreen currentScreen;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: nekoOrange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.pets, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '猫と学ぶ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '高校化学',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'ホーム',
              screen: AppScreen.home,
              currentScreen: currentScreen,
            ),
            _DrawerItem(
              icon: Icons.bar_chart,
              label: '進捗',
              screen: AppScreen.progress,
              currentScreen: currentScreen,
            ),
            _DrawerItem(
              icon: Icons.menu_book,
              label: '用語集',
              screen: AppScreen.glossary,
              currentScreen: currentScreen,
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: '設定',
              screen: AppScreen.settings,
              currentScreen: currentScreen,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.screen,
    required this.currentScreen,
  });

  final IconData icon;
  final String label;
  final AppScreen screen;
  final AppScreen currentScreen;

  @override
  Widget build(BuildContext context) {
    final selected = screen == currentScreen;
    return ListTile(
      leading: Icon(icon, color: selected ? nekoOrange : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          color: selected ? nekoOrange : null,
        ),
      ),
      selected: selected,
      selectedTileColor: nekoOrange.withValues(alpha: 0.08),
      onTap: () => _navigate(context, screen, currentScreen),
    );
  }

  void _navigate(BuildContext context, AppScreen target, AppScreen current) {
    Navigator.of(context).pop();
    if (target == current) return;

    if (target == AppScreen.home) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final Widget screen;
    switch (target) {
      case AppScreen.progress:
        screen = ProgressScreen();
        break;
      case AppScreen.glossary:
        screen = const GlossaryScreen();
        break;
      case AppScreen.settings:
        screen = const SettingsScreen();
        break;
      case AppScreen.home:
        screen = const HomeScreen();
        break;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }
}
