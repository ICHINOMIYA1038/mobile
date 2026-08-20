import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../logic/quiz_controller.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.controller});

  final QuizController controller;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const cardSize = Size(300, 400);
  static const trackPad = 24.0;
  static const _buttonGap = 12.0;
  static const _nextButtonAreaHeight = 72.0;

  final _progressRepository = ProgressRepository();
  CatAccessory _accessory = CatAccessory.none;

  @override
  void initState() {
    super.initState();
    widget.controller.init();
    _loadAccessory();
  }

  Future<void> _loadAccessory() async {
    final id = await _progressRepository.loadSelectedAccessory();
    if (!mounted) return;
    setState(() => _accessory = CatAccessory.fromId(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('猫と学ぶ高校化学')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          if (!c.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.isFinished) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      ResultScreen(controller: c, accessory: _accessory),
                ),
              );
            });
            return const SizedBox.shrink();
          }

          final q = c.currentQuestion;
          final trackSize = Size(
            cardSize.width + trackPad * 2,
            cardSize.height + trackPad * 2,
          );

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '第${c.currentIndex + 1}問 / ${c.totalCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'スコア: ${c.score}',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // 画面が低い端末では収まりきらないことがあるため、その場合はスクロールで逃がす。
                  child: SingleChildScrollView(
                    child: Center(
                      widthFactor: 1,
                      child: SizedBox(
                        width: trackSize.width,
                        height:
                            trackSize.height +
                            _buttonGap +
                            _nextButtonAreaHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: trackPad,
                              top: trackPad,
                              child: _QuizCard(
                                size: cardSize,
                                unit: q.unit,
                                question: q.question,
                                choices: q.choices,
                                selectedIndex: c.selectedIndex,
                                answerIndex: q.answerIndex,
                                explanation: q.explanation,
                                onSelect: c.selectAnswer,
                                isBookmarked: c.isCurrentBookmarked,
                                onToggleBookmark: c.toggleBookmark,
                              ),
                            ),
                            // カードの外(固定領域)に置くことで、解説文の長さに高さが左右されない。
                            Positioned(
                              left: 0,
                              right: 0,
                              top: trackSize.height + _buttonGap,
                              height: _nextButtonAreaHeight,
                              child: Center(
                                child: c.isAnswered
                                    ? ElevatedButton(
                                        onPressed: c.nextQuestion,
                                        child: const Text('つぎへ'),
                                      )
                                    : null,
                              ),
                            ),
                            // 猫はボタンに抱きつくため、一番上(最後)に描いてボタンに隠れないようにする。
                            CatMascot(
                              trackSize: trackSize,
                              waiting: c.isAnswered,
                              accessory: _accessory,
                              correct: c.isCurrentCorrect,
                            ),
                          ],
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
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.size,
    required this.unit,
    required this.question,
    required this.choices,
    required this.selectedIndex,
    required this.answerIndex,
    required this.explanation,
    required this.onSelect,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  final Size size;
  final String unit;
  final String question;
  final List<String> choices;
  final int? selectedIndex;
  final int answerIndex;
  final String explanation;
  final ValueChanged<int> onSelect;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final answered = selectedIndex != null;

    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: labMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: labMint,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('bookmark_button'),
                  onPressed: onToggleBookmark,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isBookmarked ? Icons.star : Icons.star_border,
                    color: isBookmarked
                        ? nekoOrange
                        : AppColors.of(context).textPrimary.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...List.generate(choices.length, (i) {
              return Padding(
                key: ValueKey('choice_$i'),
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChoiceButton(
                  label: choices[i],
                  state: !answered
                      ? _ChoiceState.idle
                      : i == answerIndex
                      ? _ChoiceState.correct
                      : i == selectedIndex
                      ? _ChoiceState.wrong
                      : _ChoiceState.disabled,
                  onTap: () => onSelect(i),
                ),
              );
            }),
            if (answered) ...[
              const SizedBox(height: 4),
              Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, disabled }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color bg;
    Color fg = colors.textPrimary;
    Color border;
    switch (state) {
      case _ChoiceState.idle:
        bg = colors.pageBackground;
        border = nekoOrange.withValues(alpha: 0.3);
        break;
      case _ChoiceState.correct:
        bg = labMint.withValues(alpha: 0.18);
        border = labMint;
        break;
      case _ChoiceState.wrong:
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red;
        break;
      case _ChoiceState.disabled:
        bg = Colors.grey.withValues(alpha: 0.08);
        border = Colors.transparent;
        fg = colors.textPrimary.withValues(alpha: 0.4);
        break;
    }

    return InkWell(
      onTap: state == _ChoiceState.idle ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.4),
        ),
        child: Text(label, style: TextStyle(color: fg)),
      ),
    );
  }
}
