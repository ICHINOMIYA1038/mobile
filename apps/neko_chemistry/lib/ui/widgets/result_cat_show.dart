import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'cat_mascot.dart';

enum _Tier { great, good, keepGoing }

/// 結果画面専用の猫のリアクション。得点に応じて盛り上がり方を変え、
/// 常に何かしら動き続けることで(呼吸のようなアイドル揺れ+定期的な大きな
/// フラリッシュ)、結果を見ている間に飽きさせないようにする。
class ResultCatShow extends StatefulWidget {
  const ResultCatShow({
    super.key,
    required this.ratio,
    this.size = 96,
    this.accessory = CatAccessory.none,
  });

  /// 0.0〜1.0の正答率。
  final double ratio;
  final double size;
  final CatAccessory accessory;

  _Tier get _tier {
    if (ratio >= 0.8) return _Tier.great;
    if (ratio >= 0.5) return _Tier.good;
    return _Tier.keepGoing;
  }

  @override
  State<ResultCatShow> createState() => _ResultCatShowState();
}

class _ResultCatShowState extends State<ResultCatShow>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _jump;
  late final AnimationController _effect;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _jump = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _effect = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _runFlourishLoop();
  }

  Duration get _flourishGap {
    switch (widget._tier) {
      case _Tier.great:
        return const Duration(milliseconds: 1800);
      case _Tier.good:
        return const Duration(milliseconds: 2600);
      case _Tier.keepGoing:
        return const Duration(milliseconds: 3400);
    }
  }

  /// アイドルの呼吸アニメだけでは単調になるため、一定間隔で
  /// ジャンプ(+得点が高いほど派手な演出)を挟んで表情を変える。
  Future<void> _runFlourishLoop() async {
    try {
      while (!_disposed) {
        await Future<void>.delayed(_flourishGap);
        if (_disposed) return;
        if (widget._tier != _Tier.keepGoing) {
          _effect.forward(from: 0);
        }
        await _jump.forward(from: 0).orCancel;
        if (_disposed) return;
        await _jump.reverse().orCancel;
      }
    } on TickerCanceled {
      // dispose時にキャンセルされるのは想定通り。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _idle.dispose();
    _jump.dispose();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget._tier;
    final size = widget.size;

    double bounceAmp, hugBase, hugAmp, wagSpeed;
    switch (tier) {
      case _Tier.great:
        bounceAmp = 5;
        hugBase = 0.85;
        hugAmp = 0.15;
        wagSpeed = 3.2;
        break;
      case _Tier.good:
        bounceAmp = 3.5;
        hugBase = 0.6;
        hugAmp = 0.25;
        wagSpeed = 2.2;
        break;
      case _Tier.keepGoing:
        bounceAmp = 2;
        hugBase = 0;
        hugAmp = 0;
        wagSpeed = 1.3;
        break;
    }

    return SizedBox(
      width: size * 1.8,
      height: size * 1.8,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _jump, _effect]),
        builder: (context, _) {
          final breathe = math.sin(_idle.value * 2 * math.pi);
          final jumpT = Curves.elasticOut.transform(_jump.value);
          final hugAmount = (hugBase + hugAmp * breathe).clamp(0.0, 1.0);
          final tailWag = math.sin(_idle.value * 2 * math.pi * wagSpeed);
          final jumpLift = jumpT * size * 0.4;
          final spin = tier == _Tier.great ? jumpT * 2 * math.pi : 0.0;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (tier == _Tier.great) _ConfettiBurst(t: _effect.value, size: size),
              if (tier == _Tier.good) _HeartPop(t: _effect.value, size: size),
              Transform.translate(
                offset: Offset(0, -jumpLift - breathe * bounceAmp * 0.4),
                child: Transform.rotate(
                  angle: spin,
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: CatPainter(
                      tailWag: tailWag,
                      hugAmount: hugAmount,
                      accessory: widget.accessory,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 高得点(great)時にジャンプと同時に弾ける紙吹雪。
class _ConfettiBurst extends StatelessWidget {
  const _ConfettiBurst({required this.t, required this.size});

  final double t;
  final double size;

  static const _colors = [
    nekoOrange,
    labMint,
    Color(0xFFEF6C8E),
    Color(0xFFFFD166),
  ];

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final opacity = (1 - t).clamp(0.0, 1.0);
    final centerX = size * 0.9;
    final centerY = size * 0.5;

    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(10, (i) {
        final angle = i * 2.399 + 1.0;
        final distance = t * size * 0.9 * (0.7 + 0.3 * math.sin(i * 3.1));
        final dx = math.cos(angle) * distance;
        final dy = math.sin(angle) * distance - t * size * 0.5;
        return Positioned(
          left: centerX + dx,
          top: centerY + dy,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: t * 6 + i,
              child: Container(
                width: 7,
                height: 7,
                color: _colors[i % _colors.length],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 中スコア(good)時にジャンプと同時に浮かぶハート。
class _HeartPop extends StatelessWidget {
  const _HeartPop({required this.t, required this.size});

  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return Positioned(
      top: size * 0.1 - t * size * 0.3,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Icon(
          Icons.favorite,
          color: const Color(0xFFEF6C8E),
          size: size * 0.22,
        ),
      ),
    );
  }
}
