import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../logic/maker_engine.dart';
import '../../models/maker_result.dart';
import '../../theme/app_colors.dart';
import '../../theme/sepia_filter.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/parchment_background.dart';

/// 結果画面。広告(AdBannerSlot)を出してよい唯一の画面。
///
/// [category] + [input] が同じであれば、初回表示の結果は常に同じになる
/// (`generateMakerResult` の決定的生成による)。「もう一度」ボタンは
/// [_rerollNonce] を明示的にインクリメントしたときだけ別の結果を出す。
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.category, required this.input});

  final MakerCategory category;
  final String input;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  int _rerollNonce = 0;

  late final AnimationController _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  MakerResult get _result => generateMakerResult(
    category: widget.category,
    input: widget.input,
    rerollNonce: _rerollNonce,
  );

  @override
  void initState() {
    super.initState();
    _revealController.forward();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  void _reroll() {
    setState(() => _rerollNonce++);
    _revealController.forward(from: 0);
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: _result.shareText,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = _result;
    final reveal = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOut,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('結果', style: GoogleFonts.yujiSyuku(fontSize: 20)),
      ),
      body: ParchmentBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  result.headline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 44),
                FadeTransition(
                  opacity: reveal,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(reveal),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ResultHero(category: widget.category, result: result),
                        Positioned(
                          top: -56,
                          right: 12,
                          child: Image.asset(
                            'assets/mascot/mascot_celebrate.png',
                            height: 92,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  result.detail,
                  key: const Key('resultDetail'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.shipporiMincho(
                    textStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.textSecondary, height: 1.7),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('シェア'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: colors.accent,
                          border: Border.all(color: colors.accentDeep, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.3),
                              blurRadius: 5,
                              offset: const Offset(2, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: _reroll,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.casino,
                                    size: 18,
                                    color: colors.onAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'もう一度',
                                    style: TextStyle(color: colors.onAccent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                  child: const Text('ホームに戻る'),
                ),
                const SizedBox(height: 24),
                const Center(child: AdBannerSlot()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 結果の核心(答え)を大きく見せる、古文書の証書のようなカード。
class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.category, required this.result});

  final MakerCategory category;
  final MakerResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderStrong, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 二重罫線で証書らしさを出す内枠。
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '•',
                    style: TextStyle(color: colors.accentDeep, fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(sepiaMatrix),
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '•',
                    style: TextStyle(color: colors.accentDeep, fontSize: 24),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FittedBox(
            child: Text(
              result.answer,
              key: const Key('resultAnswer'),
              textAlign: TextAlign.center,
              style: GoogleFonts.yujiSyuku(
                fontSize: 38,
                color: colors.accentDeep,
                height: 1.3,
              ),
            ),
          ),
          if (result.keywords.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final keyword in result.keywords)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '${keyword.label} ${(keyword.instinctRatio * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
