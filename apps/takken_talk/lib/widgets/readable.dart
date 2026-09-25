import 'package:flutter/material.dart';

/// iPad や横向きで本文が画面いっぱいに伸びると、1行が長すぎて読めなくなる。
/// 読みやすい幅で中央に寄せる。スマホ幅では何もしない。
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 680});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
