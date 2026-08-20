import 'package:flutter/material.dart';

import '../../data/situations.dart';
import '../theme.dart';

/// ホーム画面のシチュエーション選択タイル。実物のガチャカプセルを模した二色構成
/// (上半分が色付き、下半分が白いフタ)で、テンプレのMaterialカードから一歩離れた
/// 「手に取れるモノ」感を出す。
class SituationTile extends StatelessWidget {
  const SituationTile({
    super.key,
    required this.situation,
    required this.index,
    this.onTap,
  });

  final Situation situation;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final capsuleColor = kCapsuleColors[index % kCapsuleColors.length];
    final colors = AppColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colors.cardBackground,
            border: Border.all(
              color: colors.textPrimary.withValues(alpha: 0.08),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: capsuleColor.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // カプセル上半分。
              Expanded(
                flex: 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(color: capsuleColor),
                    Positioned(
                      top: -18,
                      left: -18,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    Icon(situation.icon, size: 34, color: Colors.white),
                  ],
                ),
              ),
              // 継ぎ目。
              Container(height: 3, color: Colors.black.withValues(alpha: 0.08)),
              // カプセル下半分(フタ)。
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        situation.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        situation.description,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
