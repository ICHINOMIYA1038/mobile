import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';

/// 猫のアクセサリーを専用に選べる着せ替え画面。
/// 上部の猫が、タップした瞬間にその場で着せ替わるリアルタイムプレビューになっている。
class AccessoryScreen extends StatefulWidget {
  AccessoryScreen({super.key, ProgressRepository? repository})
    : repository = repository ?? ProgressRepository();

  final ProgressRepository repository;

  @override
  State<AccessoryScreen> createState() => _AccessoryScreenState();
}

class _AccessoryScreenState extends State<AccessoryScreen> {
  bool _loaded = false;
  Set<String> _unlocked = const {};
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unlocked = await widget.repository.loadUnlockedAccessories();
    final selected = await widget.repository.loadSelectedAccessory();
    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _selected = selected;
      _loaded = true;
    });
  }

  Future<void> _select(String accessoryId) async {
    final next = _selected == accessoryId ? null : accessoryId;
    // 保存を待たず先に見た目を更新し、その場で着せ替わったように見せる。
    setState(() => _selected = next);
    await widget.repository.selectAccessory(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('きせかえ')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 160,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CatMascot(
                          trackSize: const Size(220, 130),
                          catSize: 76,
                          accessory: CatAccessory.fromId(_selected),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'アクセサリーをタップして着せ替えよう',
                    style: TextStyle(
                      color: AppColors.of(context).textPrimary.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: _accessories.map((accessory) {
                    final unlocked = _unlocked.contains(accessory.id);
                    final selected = _selected == accessory.id;
                    return _AccessoryChip(
                      accessory: accessory,
                      unlocked: unlocked,
                      selected: selected,
                      onTap: !unlocked ? null : () => _select(accessory.id),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

class _AccessoryInfo {
  const _AccessoryInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.hint,
  });

  final String id;
  final String label;
  final IconData icon;
  final String hint;
}

/// 進捗画面のティーザーカードで「◯/4種類」の分母として使う。
final accessoryCount = _accessories.length;

const _accessories = [
  _AccessoryInfo(
    id: ProgressRepository.accessoryRibbon,
    label: 'リボン',
    icon: Icons.card_giftcard,
    hint: '3日連続学習で解放',
  ),
  _AccessoryInfo(
    id: ProgressRepository.accessoryCrown,
    label: '王冠',
    icon: Icons.emoji_events,
    hint: '7日連続学習で解放',
  ),
  _AccessoryInfo(
    id: ProgressRepository.accessorySunglasses,
    label: 'サングラス',
    icon: Icons.visibility,
    hint: '累計50問正解で解放',
  ),
  _AccessoryInfo(
    id: ProgressRepository.accessoryScarf,
    label: 'マフラー',
    icon: Icons.checkroom,
    hint: '累計100問正解で解放',
  ),
];

class _AccessoryChip extends StatelessWidget {
  const _AccessoryChip({
    required this.accessory,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final _AccessoryInfo accessory;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = unlocked
        ? nekoOrange
        : colors.textPrimary.withValues(alpha: 0.35);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? nekoOrange.withValues(alpha: 0.15)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? nekoOrange : Colors.black.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              unlocked ? accessory.icon : Icons.lock_outline,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              accessory.label,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? (selected ? '装着中' : 'タップで装着') : accessory.hint,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
