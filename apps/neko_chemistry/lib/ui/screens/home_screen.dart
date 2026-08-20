import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../logic/quiz_controller.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';
import 'quiz_screen.dart';
import 'quiz_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _progressRepository = ProgressRepository();

  int _weakCount = 0;
  int _bookmarkCount = 0;
  StreakData _streak = const StreakData();
  CatAccessory _accessory = CatAccessory.none;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final weakIds = await _progressRepository.loadWeakQuestionIds();
    final bookmarkIds = await _progressRepository.loadBookmarkedQuestionIds();
    final streak = await _progressRepository.loadStreak();
    final accessoryId = await _progressRepository.loadSelectedAccessory();
    if (!mounted) return;
    setState(() {
      _weakCount = weakIds.length;
      _bookmarkCount = bookmarkIds.length;
      _streak = streak;
      _accessory = CatAccessory.fromId(accessoryId);
    });
  }

  void _openSetup({required bool byUnit}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => QuizSetupScreen(byUnit: byUnit)),
        )
        .then((_) => _loadProgress());
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = Size(220, 160);
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '猫と学ぶ',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: labMint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '高校化学',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 34),
                  ),
                  if (_streak.current > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: nekoOrange,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_streak.current}日連続学習中',
                          style: const TextStyle(
                            color: nekoOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: frameSize.width,
                    height: frameSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: nekoOrange.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'H₂O\nNaCl\nCH₄',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: labMint,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        CatMascot(trackSize: frameSize, accessory: _accessory),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _ModeCard(
                    icon: Icons.shuffle,
                    title: 'ランダムに挑戦',
                    subtitle: '全単元からランダムに出題',
                    color: nekoOrange,
                    onTap: () => _openSetup(byUnit: false),
                  ),
                  const SizedBox(height: 12),
                  _ModeCard(
                    icon: Icons.category,
                    title: '分野を選んで挑戦',
                    subtitle: '苦手な単元を選んで集中特訓',
                    color: labMint,
                    onTap: () => _openSetup(byUnit: true),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _weakCount == 0
                        ? null
                        : () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => QuizScreen(
                                      controller: QuizController(
                                        weakReviewOnly: true,
                                      ),
                                    ),
                                  ),
                                )
                                .then((_) => _loadProgress());
                          },
                    child: Text(
                      _weakCount == 0
                          ? '苦手問題はまだありません'
                          : '苦手問題を復習する($_weakCount問)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _bookmarkCount == 0
                        ? null
                        : () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => QuizScreen(
                                      controller: QuizController(
                                        bookmarkOnly: true,
                                      ),
                                    ),
                                  ),
                                )
                                .then((_) => _loadProgress());
                          },
                    child: Text(
                      _bookmarkCount == 0
                          ? 'ブックマークはまだありません'
                          : 'ブックマークを復習する($_bookmarkCount問)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.textPrimary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
