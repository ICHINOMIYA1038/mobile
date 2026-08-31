import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../logic/inspection_scorer.dart';
import '../../models/inspection.dart';
import 'ar_map_screen.dart';
import 'before_after_screen.dart';
import 'calibration_screen.dart';
import 'inspection_flow_screen.dart';
import 'inspection_list_screen.dart';
import 'inspection_result_screen.dart';
import 'meter_screen.dart';

/// ホーム。「部屋の防音診断」を主役に、内見診断・ARマップ・対策の記録・
/// 騒音計への入口を並べる。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Shield'),
        actions: [
          IconButton(
            tooltip: '騒音計の校正',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: 'calibration'),
                builder: (_) => const CalibrationScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              '部屋の防音診断',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'どこから・何の音が・どれだけ入ってくるかを測って、効く対策だけを選ぶ。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 20),
            _FeatureCard(
              icon: Icons.home_work_outlined,
              title: '内見診断',
              subtitle: '3分で防音スコア。窓・壁・ドアの弱点と壁の重さを判定。物件同士で比較。',
              accent: scheme.primary,
              onTap: () => _startInspection(context),
            ),
            _FeatureCard(
              icon: Icons.view_in_ar_outlined,
              title: '音の侵入マップ',
              subtitle: '壁や窓に沿ってかざすと、音が大きい場所が空間に色で浮かび上がる。',
              accent: scheme.secondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'ar_map'),
                  builder: (_) => const ArMapScreen(),
                ),
              ),
            ),
            _FeatureCard(
              icon: Icons.build_outlined,
              title: '対策の効果を検証',
              subtitle: '対策の前後で計測し、何dB下がったかを記録。予測との差も確認。',
              accent: scheme.tertiary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'before_after'),
                  builder: (_) => const BeforeAfterScreen(),
                ),
              ),
            ),
            _FeatureCard(
              icon: Icons.speed_outlined,
              title: '騒音計',
              subtitle: '今の騒音レベルを計測。音源推定と対策シミュレーターつき。',
              accent: scheme.outline,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'meter'),
                  builder: (_) => const MeterScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: services.inspections,
              builder: (context, _) {
                final list = services.inspections.inspections;
                if (list.isEmpty) return const SizedBox.shrink();
                return _RecentInspections(inspections: list.take(3).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startInspection(BuildContext context) async {
    final services = AppScope.of(context);
    final granted = await services.soundMeter.checkAndRequestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('マイクの利用が許可されていません。設定アプリからマイクへのアクセスを許可してください。'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'inspection_flow'),
        builder: (_) => const InspectionFlowScreen(),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentInspections extends StatelessWidget {
  const _RecentInspections({required this.inspections});

  final List<Inspection> inspections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('最近の診断', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'inspection_list'),
                  builder: (_) => const InspectionListScreen(),
                ),
              ),
              child: const Text('すべて見る・比較'),
            ),
          ],
        ),
        for (final inspection in inspections)
          _InspectionTile(inspection: inspection, scheme: scheme),
      ],
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.inspection, required this.scheme});

  final Inspection inspection;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final score = const InspectionScorer().score(inspection);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ScoreChip(score: score),
      title: Text(inspection.name),
      subtitle: Text(
        score.weakest == null ? '弱点なし' : '弱点: ${score.weakest!.label}',
        style: TextStyle(color: scheme.outline),
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.outline),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'inspection_result'),
          builder: (_) => InspectionResultScreen(inspection: inspection),
        ),
      ),
    );
  }
}

/// スコアを丸いチップで見せる(一覧・比較で共通)。
class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key, required this.score});

  final InspectionScore score;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, score.score);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        score.grade,
        style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 18),
      ),
    );
  }
}

Color scoreColor(BuildContext context, int score) {
  final scheme = Theme.of(context).colorScheme;
  if (score >= 65) return scheme.secondary;
  if (score >= 50) return scheme.primary;
  return scheme.tertiary;
}
