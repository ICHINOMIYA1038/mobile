import 'package:flutter/material.dart';

import '../../data/notification_service.dart';
import '../../data/progress_repository.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _progressRepository = ProgressRepository();

  bool _notificationsEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _progressRepository.loadNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _loaded = true;
    });
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学習データをリセットしますか?'),
        content: const Text(
          '苦手問題・ブックマーク・正答率・連続記録・解放したアクセサリーがすべて消えます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'リセットする',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _progressRepository.resetAll();
    await NotificationService().cancelAll();
    if (!mounted) return;
    setState(() => _notificationsEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('学習データをリセットしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      drawer: const AppDrawer(currentScreen: AppScreen.settings),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('復習リマインダー'),
                    subtitle: const Text('毎日19時ごろに通知でお知らせします'),
                    value: _notificationsEnabled,
                    activeTrackColor: nekoOrange,
                    onChanged: (value) async {
                      final notificationService = NotificationService();
                      if (value) {
                        final granted = await notificationService
                            .requestPermission();
                        await _progressRepository.setNotificationsEnabled(
                          granted,
                        );
                        if (granted) {
                          await notificationService.scheduleDailyReminder();
                        }
                        if (!mounted) return;
                        setState(() => _notificationsEnabled = granted);
                      } else {
                        await _progressRepository.setNotificationsEnabled(
                          false,
                        );
                        await notificationService.cancelAll();
                        if (!mounted) return;
                        setState(() => _notificationsEnabled = false);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.brightness_6_outlined,
                      color: nekoOrange,
                    ),
                    title: const Text('画面の明るさ'),
                    subtitle: const Text('端末のライト/ダーク設定に自動で合わせています'),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text('学習データをリセット'),
                    subtitle: const Text('苦手問題・進捗・連続記録をすべて削除します'),
                    onTap: _confirmReset,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '猫と学ぶ高校化学 v1.0.0',
                    style: TextStyle(
                      color: colors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
