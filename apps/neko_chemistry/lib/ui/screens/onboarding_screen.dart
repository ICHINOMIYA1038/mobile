import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../theme.dart';
import '../widgets/cat_mascot.dart';
import 'home_screen.dart';

/// 初回起動時にだけ表示する、簡単な使い方説明。
/// 「はじめる」を押すとホーム画面に遷移し、二度と表示しないようフラグを保存する。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

const _pages = [
  _OnboardingPage(
    title: 'ようこそ!',
    description: '猫と一緒に高校化学を楽しく学べるアプリです。\nタップすると猫が反応してくれます。',
    icon: Icons.pets,
    color: nekoOrange,
  ),
  _OnboardingPage(
    title: '2つの挑戦モード',
    description: '「ランダムに挑戦」で全単元から出題、\n「分野を選んで挑戦」で苦手な単元だけ集中特訓できます。',
    icon: Icons.shuffle,
    color: labMint,
  ),
  _OnboardingPage(
    title: '苦手問題は自動で記録',
    description: '間違えた問題は自動で「苦手問題」に記録され、\nホーム画面からいつでも復習できます。\n気になる問題は★でブックマークもできます。',
    icon: Icons.star,
    color: nekoOrange,
  ),
  _OnboardingPage(
    title: '毎日続けて猫を着飾ろう',
    description: '毎日学習を続けたり、たくさん正解したりすると、\n猫にリボンや王冠などの飾りが増えていきます。',
    icon: Icons.emoji_events,
    color: labMint,
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _progressRepository = ProgressRepository();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _progressRepository.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _next() {
    if (_pageIndex == _pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLast = _pageIndex == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('スキップ'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 140,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: page.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  page.icon,
                                  color: page.color,
                                  size: 44,
                                ),
                              ),
                              const Positioned(
                                bottom: -10,
                                child: CatMascot(
                                  trackSize: Size(120, 90),
                                  catSize: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textPrimary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final active = index == _pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? nekoOrange
                        : nekoOrange.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'はじめる' : '次へ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
