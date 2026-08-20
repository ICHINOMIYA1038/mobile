import 'package:flutter/material.dart';

import '../../data/ad_service.dart';
import '../../data/history_repository.dart';
import '../../data/ng_settings_repository.dart';
import '../../data/ng_tags.dart';
import '../../data/notification_service.dart';
import '../theme.dart';
import '../widgets/dashed_border.dart';
import '../widgets/dot_pattern_background.dart';
import '../widgets/ng_tag_chip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ngRepository = NgSettingsRepository();
  final _notificationService = NotificationService();
  final _historyRepository = HistoryRepository();

  Set<String> _disabledTagIds = {};
  bool _reminderEnabled = false;
  int _reminderMinutes = 19 * 60;
  bool _privacyOptionsRequired = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final disabled = await _ngRepository.loadDisabledTagIds();
    final reminderEnabled = await _notificationService.loadEnabled();
    final minutes = await _notificationService.loadMinutesSinceMidnight();
    final privacyRequired = await AdService.isPrivacyOptionsRequired();
    if (!mounted) return;
    setState(() {
      _disabledTagIds = disabled;
      _reminderEnabled = reminderEnabled;
      _reminderMinutes = minutes;
      _privacyOptionsRequired = privacyRequired;
      _loading = false;
    });
  }

  Future<void> _toggleTag(String tagId) async {
    await _ngRepository.toggleTag(tagId);
    setState(() {
      if (!_disabledTagIds.add(tagId)) {
        _disabledTagIds.remove(tagId);
      }
    });
  }

  Future<void> _onReminderChanged(bool enabled) async {
    if (enabled) {
      await _notificationService.requestPermission();
      await _notificationService.setEnabled(true);
      await _notificationService.scheduleDailyReminder(
        minutesSinceMidnight: _reminderMinutes,
      );
    } else {
      await _notificationService.setEnabled(false);
      await _notificationService.cancelAll();
    }
    if (!mounted) return;
    setState(() => _reminderEnabled = enabled);
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: _reminderMinutes ~/ 60,
      minute: _reminderMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final minutes = picked.hour * 60 + picked.minute;
    await _notificationService.setMinutesSinceMidnight(minutes);
    if (_reminderEnabled) {
      await _notificationService.scheduleDailyReminder(
        minutesSinceMidnight: minutes,
      );
    }
    if (!mounted) return;
    setState(() => _reminderMinutes = minutes);
  }

  Future<void> _resetHistory() async {
    await _historyRepository.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('履歴をリセットしました')));
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: _reminderMinutes ~/ 60,
      minute: _reminderMinutes % 60,
    );
    final colors = AppColors.of(context);
    final borderColor = colors.textMuted.withValues(alpha: 0.5);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: DotPatternBackground(
        dotColor: colors.dotPattern,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SettingsSection(
                    borderColor: borderColor,
                    fillColor: colors.cardBackground,
                    title: '表示しないテーマ',
                    subtitle: 'OFFにしたテーマのお題は抽選対象から外れます',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kNgTags
                          .map(
                            (tag) => NgTagChip(
                              tag: tag,
                              selected: !_disabledTagIds.contains(tag.id),
                              onSelected: (_) => _toggleTag(tag.id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    borderColor: borderColor,
                    fillColor: colors.cardBackground,
                    title: '配信前リマインダー',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('毎日決まった時刻に通知'),
                          value: _reminderEnabled,
                          onChanged: _onReminderChanged,
                        ),
                        if (_reminderEnabled)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('通知時刻'),
                            trailing: Text(time.format(context)),
                            onTap: _pickTime,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    borderColor: borderColor,
                    fillColor: colors.cardBackground,
                    title: 'データ',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('履歴をリセット'),
                      subtitle: const Text('直近に出したお題の記録を消去します'),
                      onTap: _resetHistory,
                    ),
                  ),
                  if (_privacyOptionsRequired) ...[
                    const SizedBox(height: 16),
                    _SettingsSection(
                      borderColor: borderColor,
                      fillColor: colors.cardBackground,
                      title: '広告',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('広告の同意設定を見直す'),
                        onTap: () => AdService.showPrivacyOptionsForm(),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// 設定画面の各項目をまとめる、破線ボーダーのカード。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.borderColor,
    required this.fillColor,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final Color borderColor;
  final Color fillColor;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DashedBorderContainer(
      color: borderColor,
      fillColor: fillColor,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
