import 'package:flutter/material.dart';

import '../../data/notification_service.dart';
import '../../data/progress_repository.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _progressRepository = ProgressRepository();

  bool _notificationsEnabled = false;
  int _reminderMinutes = 19 * 60;
  bool _loaded = false;
  CatAccessory _accessory = CatAccessory.none;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _progressRepository.loadNotificationsEnabled();
    final minutes = await _progressRepository.loadReminderMinutes();
    final accessoryId = await _progressRepository.loadSelectedAccessory();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _reminderMinutes = minutes;
      _accessory = CatAccessory.fromId(accessoryId);
      _loaded = true;
    });
  }

  TimeOfDay get _reminderTime =>
      TimeOfDay(hour: _reminderMinutes ~/ 60, minute: _reminderMinutes % 60);

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;

    final minutes = picked.hour * 60 + picked.minute;
    await _progressRepository.setReminderMinutes(minutes);
    if (!mounted) return;
    setState(() => _reminderMinutes = minutes);

    if (_notificationsEnabled) {
      await NotificationService().scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学習データをリセットしますか?'),
        content: const Text(
          '苦手問題・ブックマーク・正答率・連続記録・学習カレンダー・暗記カードの記録・'
          '解放したアクセサリーやバッジがすべて消えます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセットする', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _progressRepository.resetAll();
    await NotificationService().cancelAll();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = false;
      _accessory = CatAccessory.none;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('学習データをリセットしました')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 74,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CatMascot(
                          trackSize: const Size(160, 60),
                          catSize: 38,
                          accessory: _accessory,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('復習リマインダー'),
                        subtitle: Text(
                          '毎日${_reminderTime.hour.toString().padLeft(2, '0')}:'
                          '${_reminderTime.minute.toString().padLeft(2, '0')}ごろに通知でお知らせします',
                        ),
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
                              await notificationService.scheduleDailyReminder(
                                hour: _reminderTime.hour,
                                minute: _reminderTime.minute,
                              );
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
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.access_time,
                          color: nekoOrange,
                        ),
                        title: const Text('通知時刻'),
                        subtitle: Text(_reminderTime.format(context)),
                        onTap: _pickReminderTime,
                      ),
                    ],
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
      child: Material(color: Colors.transparent, child: child),
    );
  }
}
