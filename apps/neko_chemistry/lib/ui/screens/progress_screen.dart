import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../data/units.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';

class ProgressScreen extends StatefulWidget {
  ProgressScreen({super.key, ProgressRepository? repository})
    : repository = repository ?? ProgressRepository();

  final ProgressRepository repository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
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

class _ProgressSnapshot {
  const _ProgressSnapshot({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.unitStats,
    required this.streak,
    required this.unlocked,
    required this.selectedAccessory,
  });

  final int totalAnswered;
  final int totalCorrect;
  final Map<String, UnitStats> unitStats;
  final StreakData streak;
  final Set<String> unlocked;
  final String? selectedAccessory;
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<_ProgressSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressSnapshot> _load() async {
    final repo = widget.repository;
    final results = await Future.wait([
      repo.loadTotalAnswered(),
      repo.loadTotalCorrect(),
      repo.loadUnitStats(),
      repo.loadStreak(),
      repo.loadUnlockedAccessories(),
      repo.loadSelectedAccessory(),
    ]);
    return _ProgressSnapshot(
      totalAnswered: results[0] as int,
      totalCorrect: results[1] as int,
      unitStats: results[2] as Map<String, UnitStats>,
      streak: results[3] as StreakData,
      unlocked: results[4] as Set<String>,
      selectedAccessory: results[5] as String?,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('進捗')),
      drawer: const AppDrawer(currentScreen: AppScreen.progress),
      body: FutureBuilder<_ProgressSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SummaryCard(data: data),
              const SizedBox(height: 20),
              Text(
                '単元別の正答率',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...kAllUnits.map(
                (unit) =>
                    _UnitBar(unit: unit, stats: data.unitStats[unit]),
              ),
              const SizedBox(height: 20),
              Text('猫のアクセサリー', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _AccessoryGrid(
                data: data,
                repository: widget.repository,
                onChanged: _reload,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _ProgressSnapshot data;

  @override
  Widget build(BuildContext context) {
    final accuracy = data.totalAnswered == 0
        ? 0
        : (data.totalCorrect / data.totalAnswered * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatColumn(label: '累計回答', value: '${data.totalAnswered}問'),
          _StatColumn(label: '正答率', value: '$accuracy%'),
          _StatColumn(
            label: '連続学習',
            value: '${data.streak.current}日',
          ),
          _StatColumn(label: '自己ベスト', value: '${data.streak.best}日'),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: nekoOrange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.of(context).textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UnitBar extends StatelessWidget {
  const _UnitBar({required this.unit, required this.stats});

  final String unit;
  final UnitStats? stats;

  @override
  Widget build(BuildContext context) {
    final answered = stats?.answered ?? 0;
    final accuracy = stats?.accuracy ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(unit, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 16, color: nekoOrange.withValues(alpha: 0.12)),
                  FractionallySizedBox(
                    widthFactor: answered == 0 ? 0 : accuracy.clamp(0, 1),
                    child: Container(height: 16, color: labMint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              answered == 0 ? '未出題' : '${(accuracy * 100).round()}%',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessoryGrid extends StatelessWidget {
  const _AccessoryGrid({
    required this.data,
    required this.repository,
    required this.onChanged,
  });

  final _ProgressSnapshot data;
  final ProgressRepository repository;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _accessories.map((accessory) {
        final unlocked = data.unlocked.contains(accessory.id);
        final selected = data.selectedAccessory == accessory.id;
        return _AccessoryChip(
          accessory: accessory,
          unlocked: unlocked,
          selected: selected,
          onTap: !unlocked
              ? null
              : () async {
                  await repository.selectAccessory(selected ? null : accessory.id);
                  onChanged();
                },
        );
      }).toList(),
    );
  }
}

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
