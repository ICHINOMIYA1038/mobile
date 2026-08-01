import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/maker_result.dart';
import '../../theme/app_colors.dart';
import '../../theme/sepia_filter.dart';

/// ホーム画面に並ぶ、カテゴリ選択カード。
/// 少しだけ傾けて「紙を手で貼ったノート」のような不揃いさを出している。
class MakerCategoryCard extends StatelessWidget {
  const MakerCategoryCard({
    super.key,
    required this.category,
    required this.emoji,
    required this.onTap,
  });

  final MakerCategory category;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tiltDegrees = (category.index.isEven ? -1 : 1) * (0.8 + category.index * 0.5);

    return Transform.rotate(
      angle: tiltDegrees * 3.1415926535 / 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentSurface,
                      border: Border.all(color: colors.borderStrong, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(sepiaMatrix),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: GoogleFonts.yujiSyuku(
                            fontSize: 20,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
