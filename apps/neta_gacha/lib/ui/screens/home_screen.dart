import 'package:flutter/material.dart';

import '../../data/situations.dart';
import '../theme.dart';
import '../widgets/capsule_machine_illustration.dart';
import '../widgets/dot_pattern_background.dart';
import '../widgets/situation_tile.dart';
import 'custom_prompt_screen.dart';
import 'favorites_screen.dart';
import 'roulette_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('配信ネタガチャ'),
        actions: [
          IconButton(
            tooltip: 'お気に入り',
            icon: const Icon(Icons.star_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'カスタムお題',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomPromptScreen()),
            ),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: DotPatternBackground(
        dotColor: colors.dotPattern,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const CapsuleMachineIllustration(height: 190),
                  const SizedBox(height: 8),
                  Text(
                    'カプセルをひとつ選んで、配信のネタを引こう',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final situation = kSituations[index];
                    return SituationTile(
                      situation: situation,
                      index: index,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RouletteScreen(situationId: situation.id),
                        ),
                      ),
                    );
                  },
                  childCount: kSituations.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
