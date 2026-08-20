import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/progress_repository.dart';
import '../../data/units.dart';
import '../../logic/cat_type_diagnosis.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';
import 'accessory_screen.dart';

class ProgressScreen extends StatefulWidget {
  ProgressScreen({super.key, ProgressRepository? repository})
    : repository = repository ?? ProgressRepository();

  final ProgressRepository repository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _BadgeInfo {
  const _BadgeInfo({
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

const _badges = [
  _BadgeInfo(
    id: ProgressRepository.badgeFirstStep,
    label: 'はじめの一歩',
    icon: Icons.flag,
    hint: '1問に挑戦',
  ),
  _BadgeInfo(
    id: ProgressRepository.badgeAllUnits,
    label: '全単元制覇',
    icon: Icons.public,
    hint: '全単元で1問以上正解',
  ),
  _BadgeInfo(
    id: ProgressRepository.badgePerfectClear,
    label: '満点クリア',
    icon: Icons.star,
    hint: '1回のクイズで満点',
  ),
  _BadgeInfo(
    id: ProgressRepository.badgeWeekStreak,
    label: '一週間継続',
    icon: Icons.calendar_month,
    hint: '7日連続学習',
  ),
  _BadgeInfo(
    id: ProgressRepository.badgeCentury,
    label: '100問突破',
    icon: Icons.military_tech,
    hint: '累計100問回答',
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
    required this.studyLog,
    required this.unlockedBadges,
  });

  final int totalAnswered;
  final int totalCorrect;
  final Map<String, UnitStats> unitStats;
  final StreakData streak;
  final Set<String> unlocked;
  final String? selectedAccessory;
  final Map<String, int> studyLog;
  final Set<String> unlockedBadges;
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
      repo.loadStudyLog(),
      repo.loadUnlockedBadges(),
    ]);
    return _ProgressSnapshot(
      totalAnswered: results[0] as int,
      totalCorrect: results[1] as int,
      unitStats: results[2] as Map<String, UnitStats>,
      streak: results[3] as StreakData,
      unlocked: results[4] as Set<String>,
      selectedAccessory: results[5] as String?,
      studyLog: results[6] as Map<String, int>,
      unlockedBadges: results[7] as Set<String>,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('進捗')),
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
              Center(
                child: SizedBox(
                  width: 180,
                  height: 84,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CatMascot(
                        trackSize: const Size(180, 68),
                        catSize: 42,
                        accessory: CatAccessory.fromId(data.selectedAccessory),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SummaryCard(data: data),
              const SizedBox(height: 20),
              _ShareCard(data: data),
              const SizedBox(height: 20),
              _CatTypeCard(result: diagnoseCatType(data.unitStats)),
              const SizedBox(height: 20),
              Text(
                '学習カレンダー',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _StudyHeatmap(studyLog: data.studyLog),
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
              Text('実績バッジ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _BadgeGrid(unlockedBadges: data.unlockedBadges),
              const SizedBox(height: 20),
              _AccessoryTeaserCard(
                unlockedCount: data.unlocked.length,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AccessoryScreen(repository: widget.repository),
                    ),
                  );
                  _reload();
                },
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

/// 進捗画面からきせかえ専用画面へ誘導するカード。
class _AccessoryTeaserCard extends StatelessWidget {
  const _AccessoryTeaserCard({
    required this.unlockedCount,
    required this.onTap,
  });

  final int unlockedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: nekoOrange.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: nekoOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checkroom, color: nekoOrange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '猫のきせかえ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$unlockedCount / $accessoryCount種類のアクセサリーを解放中',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.textPrimary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 学習記録を猫のイラストと一緒にかわいい画像にしてシェアするカード。
class _ShareCard extends StatefulWidget {
  const _ShareCard({required this.data});

  final _ProgressSnapshot data;

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/neko_chemistry_share.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '「猫と学ぶ高校化学」で学習中です🐱',
        subject: '猫と学ぶ高校化学の学習記録',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('シェア画像の作成に失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final accuracy = data.totalAnswered == 0
        ? 0
        : (data.totalCorrect / data.totalAnswered * 100).round();
    final accessory = CatAccessory.fromId(data.selectedAccessory);

    return Column(
      children: [
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  nekoOrange.withValues(alpha: 0.18),
                  labMint.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text(
                  '猫と学ぶ高校化学',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: inkBrown),
                ),
                const SizedBox(height: 12),
                CustomPaint(
                  size: const Size(72, 72),
                  painter: CatPainter(tailWag: 0, accessory: accessory),
                ),
                const SizedBox(height: 12),
                Text(
                  '正答率 $accuracy%',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: inkBrown),
                ),
                const SizedBox(height: 6),
                Text(
                  '連続学習 ${data.streak.current}日・累計 ${data.totalAnswered}問',
                  style: const TextStyle(fontSize: 13, color: inkBrown),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _sharing ? null : _share,
          icon: const Icon(Icons.ios_share, size: 18),
          label: Text(_sharing ? '作成中...' : '学習記録をシェア'),
        ),
      ],
    );
  }
}

/// 単元別の正答数から診断した「猫タイプ」を表示するカード。
class _CatTypeCard extends StatelessWidget {
  const _CatTypeCard({required this.result});

  final CatTypeResult result;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (!result.isDiagnosable) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: colors.textPrimary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '猫タイプ診断: 各分野を5問以上解くと診断できます',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textPrimary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final info = result.info!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, color: info.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'あなたは${info.label}!',
                  style: TextStyle(fontWeight: FontWeight.w800, color: info.color),
                ),
                const SizedBox(height: 4),
                Text(
                  info.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 直近10週間の学習量を、日付ごとの回答数に応じて色の濃さで示すヒートマップ。
class _StudyHeatmap extends StatelessWidget {
  const _StudyHeatmap({required this.studyLog});

  final Map<String, int> studyLog;
  static const _weeks = 10;

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Color _heatColor(int count) {
    if (count <= 0) return Colors.grey.withValues(alpha: 0.12);
    if (count == 1) return labMint.withValues(alpha: 0.35);
    if (count <= 3) return labMint.withValues(alpha: 0.65);
    return labMint;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    // 直近10週間がちょうど月曜始まりのマス目になるよう、始点をその週の月曜まで戻す。
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final gridStart = startOfThisWeek.subtract(Duration(days: (_weeks - 1) * 7));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: List.generate(_weeks, (week) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: List.generate(7, (weekday) {
                final day = gridStart.add(Duration(days: week * 7 + weekday));
                final key = _dateKey(day);
                final isFuture = key.compareTo(todayKey) > 0;
                final count = studyLog[key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isFuture ? Colors.transparent : _heatColor(count),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

/// 実績バッジを一覧表示する。アクセサリーと違い選択操作はなく、達成有無だけを示す。
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.unlockedBadges});

  final Set<String> unlockedBadges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _badges.map((badge) {
        return _BadgeChip(
          badge: badge,
          unlocked: unlockedBadges.contains(badge.id),
        );
      }).toList(),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.unlocked});

  final _BadgeInfo badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = unlocked ? labMint : colors.textPrimary.withValues(alpha: 0.35);
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? labMint : Colors.black.withValues(alpha: 0.08),
          width: unlocked ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(unlocked ? badge.icon : Icons.lock_outline, color: color),
          const SizedBox(height: 6),
          Text(
            badge.label,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? '達成済み' : badge.hint,
            style: TextStyle(fontSize: 9, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
