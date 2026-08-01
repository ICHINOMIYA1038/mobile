import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/maker_result.dart';
import '../../theme/app_colors.dart';
import '../widgets/maker_category_card.dart';
import '../widgets/parchment_background.dart';
import 'input_screen.dart';

/// カテゴリ選択画面。広告は一切置かない。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      body: ParchmentBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ネタメーカー',
                          style: GoogleFonts.yujiSyuku(
                            fontSize: 40,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '• ―― 手帳 ―― •',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '名前を入れるだけ。\n診断を選んでね。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/mascot/mascot_wave.png',
                    height: 108,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              for (final category in MakerCategory.values) ...[
                MakerCategoryCard(
                  category: category,
                  emoji: category.emoji,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InputScreen(category: category),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
