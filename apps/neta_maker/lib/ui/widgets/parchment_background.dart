import 'package:flutter/material.dart';

/// 全画面共通の背景。自作の羊皮紙テクスチャ画像を敷くだけの、
/// 派手なグローや発光アニメーションを一切使わないシンプルな背景。
///
/// 「魔女の羊皮紙・アンティーク占い師の手帳」という世界観を、
/// 経年変化した紙の質感だけで表現する。
class ParchmentBackground extends StatelessWidget {
  const ParchmentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Scaffold.body の中身がスクロール可能なコンテンツ(SingleChildScrollViewなど)の
    // 場合、何も対策しないとコンテンツの高さぶんしか背景が描画されず、画面の
    // 余った部分が塗り残されてしまう。SizedBox.expand + Positioned.fill で
    // 常に画面いっぱいのサイズを強制する。
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/textures/parchment.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      ),
    );
  }
}
