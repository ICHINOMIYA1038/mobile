import 'package:flutter/material.dart';

import '../../models/prompt.dart';
import '../theme.dart';

/// 抽選結果・お気に入り一覧で共通して使う、紙のメモを破り取ったような付箋カード。
/// わずかに傾け、上下の縁をギザギザにして「印刷されたテンプレ」から離す。
class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.prompt,
    required this.isFavorite,
    this.onToggleFavorite,
    this.onShare,
    this.tiltTurns = -0.012,
  });

  final Prompt prompt;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onShare;

  /// カードの傾き(1.0 = 360度)。一覧に複数並ぶときに少しずつ変えると自然に見える。
  final double tiltTurns;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return RotationTransition(
      turns: AlwaysStoppedAnimation(tiltTurns),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: colors.paperShadow,
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const _TornEdgeClipper(),
          child: Container(
            color: colors.paperBackground,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prompt.text, style: handwritingStyle(context)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onToggleFavorite != null)
                      IconButton(
                        onPressed: onToggleFavorite,
                        icon: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isFavorite ? gachaOrange : colors.textMuted,
                        ),
                        tooltip: isFavorite ? 'お気に入り解除' : 'お気に入りに追加',
                      ),
                    if (onShare != null)
                      IconButton(
                        onPressed: onShare,
                        icon: Icon(
                          Icons.ios_share_rounded,
                          color: colors.textMuted,
                        ),
                        tooltip: '共有',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 上下の縁を紙をちぎったようなギザギザにするクリッパー。
class _TornEdgeClipper extends CustomClipper<Path> {
  const _TornEdgeClipper();

  static const _toothWidth = 14.0;
  static const _toothDepth = 4.0;

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, _toothDepth);
    _zigzagEdge(path, size.width, fromLeft: true);
    path.lineTo(size.width, size.height - _toothDepth);
    _zigzagEdge(path, size.width, fromLeft: false, baseY: size.height);
    path.close();
    return path;
  }

  void _zigzagEdge(
    Path path,
    double width, {
    required bool fromLeft,
    double baseY = 0,
  }) {
    final teeth = (width / _toothWidth).floor();
    for (var i = 1; i <= teeth; i++) {
      final x = fromLeft ? i * _toothWidth : width - i * _toothWidth;
      final y = baseY + (i.isEven ? -_toothDepth : _toothDepth);
      path.lineTo(x, y);
    }
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
