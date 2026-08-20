import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/situations.dart';
import '../../logic/roulette_controller.dart';
import '../theme.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/capsule_reveal_animation.dart';
import '../widgets/dot_pattern_background.dart';
import '../widgets/gacha_knob_button.dart';
import '../widgets/prompt_card.dart';
import '../widgets/timer_sheet.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key, required this.situationId});

  final String situationId;

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  late final RouletteController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RouletteController(situationId: widget.situationId)
      ..addListener(_onChanged)
      ..load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    final ok = await _controller.draw();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('引けるお題がありません。NG設定を見直してみてください。'),
        ),
      );
    }
  }

  void _share() {
    final prompt = _controller.currentPrompt;
    if (prompt == null) return;
    SharePlus.instance.share(
      ShareParams(text: '${prompt.text}\n#配信ネタガチャ'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final situation = situationById(widget.situationId);
    final situationIndex = kSituations.indexWhere(
      (s) => s.id == widget.situationId,
    );
    final capsuleColor = kCapsuleColors[situationIndex % kCapsuleColors.length];
    final prompt = _controller.currentPrompt;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(situation.label)),
      body: DotPatternBackground(
        dotColor: colors.dotPattern,
        child: SafeArea(
          child: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: prompt == null
                                ? Text(
                                    'ノブをひねってお題を引いてみよう',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  )
                                : CapsuleRevealAnimation(
                                    key: ValueKey(_controller.drawSequence),
                                    capsuleColor: capsuleColor,
                                    child: PromptCard(
                                      prompt: prompt,
                                      isFavorite: _controller.currentIsFavorite,
                                      onToggleFavorite:
                                          _controller.toggleFavorite,
                                      onShare: _share,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GachaKnobButton(onPressed: _draw),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => TimerSheet.show(context),
                        icon: const Icon(Icons.timer_rounded),
                        label: const Text('タイマー'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: const AdBannerSlot(),
    );
  }
}
