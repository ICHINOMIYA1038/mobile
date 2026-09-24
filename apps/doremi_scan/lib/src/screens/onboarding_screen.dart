import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 初回起動のみ表示する3枚のガイド。
/// 認識は1回20〜30秒かかる高コスト動線なので、
/// 「きれいに撮るコツ」を先に知ってもらい、1回目の成功率を上げる。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.music_note_rounded,
      '楽譜を撮るだけで\nドレミのふりがな',
      '撮影した楽譜の音符に、ドレミが自動でつきます。譜読みが苦手でも、その場で弾き始められます。'
    ),
    (
      Icons.photo_camera_rounded,
      'きれいに撮るコツ',
      '紙の楽譜は「真上から・明るく・影なし」で。スマホやPCの画面の楽譜は、撮影よりスクリーンショットのほうがずっときれいに読めます。'
    ),
    (
      Icons.edit_note_rounded,
      '直せる・残せる・印刷できる',
      '違う音はタップで修正、読み落としもタップで追加。結果は自動で保存され、印刷やPDFで共有もできます。'
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    const Text('スキップ', style: TextStyle(color: AppColors.muted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final (icon, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 96, color: AppColors.brand),
                        const SizedBox(height: 28),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                                color: AppColors.ink)),
                        const SizedBox(height: 16),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.8,
                                color: AppColors.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.brand : AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    Navigator.of(context).pop();
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  }
                },
                child: Text(last ? 'はじめる' : 'つぎへ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
