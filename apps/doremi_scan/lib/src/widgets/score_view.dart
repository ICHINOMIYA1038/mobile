import 'dart:io';

import 'package:flutter/material.dart';

import '../models/score.dart';
import '../theme/app_theme.dart';

/// 元の楽譜写真の上に、各音符のドレミ（ルビ）を重ねて表示する。
class ScoreView extends StatelessWidget {
  final RecognizedScore score;
  const ScoreView({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final file = File(score.sourceImagePath);
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = w / (score.aspect <= 0 ? 1 : score.aspect);
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  if (file.existsSync())
                    Positioned.fill(child: Image.file(file, fit: BoxFit.fill)),
                  // ルビ（音符の少し上）
                  for (final n in score.notes)
                    Positioned(
                      left: n.xFrac * w - 16,
                      // 五線上端の少し上に。負にならないようクランプ。
                      top: (n.yFrac * h - 22).clamp(0.0, h - 16),
                      width: 32,
                      child: Center(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 1),
                          color: Colors.white.withValues(alpha: 0.72),
                          child: Text(
                            n.ruby,
                            style: const TextStyle(
                              color: AppColors.brandDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
