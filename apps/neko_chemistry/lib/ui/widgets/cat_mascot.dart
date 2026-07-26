import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// クイズカードの枠の周りを歩き回る猫。[waiting]がtrueになっても、
/// すぐには止まらずいつも通り歩き続け、枠の下にある「つぎへ」ボタンの
/// 位置(下辺中央から少し降りたところ)まで来たところで初めてぶつかって止まり、
/// 抱きつくポーズになる。[waiting]がfalseに戻ると離れてまた歩き出す。
/// タップすると跳ねて鳴く。
///
/// AIで生成した一枚絵をそのまま歩行アニメのコマ割りに使うと、生成のたびに
/// 毛色・体型がブレてパラパラ漫画のように破綻するため、見た目はCustomPainterで
/// 手続き的に描き、動き(歩行・尻尾・タップ反応・抱きつき)は全てコード側のTweenで作っている。
class CatMascot extends StatefulWidget {
  const CatMascot({
    super.key,
    required this.trackSize,
    this.catSize = 46,
    this.waiting = false,
    this.accessory = CatAccessory.none,
  });

  /// 猫が歩く矩形トラックのサイズ。この矩形の辺に沿って周回する。
  final Size trackSize;
  final double catSize;

  /// trueの間、下辺中央の「つぎへ」ボタン位置まで来たら止まって待つ。
  final bool waiting;

  /// 猫が身につけている小物(進捗画面で選んだもの)。
  final CatAccessory accessory;

  @override
  State<CatMascot> createState() => _CatMascotState();
}

class _CatMascotState extends State<CatMascot> with TickerProviderStateMixin {
  static const _walkSeconds = 7.0;
  static const _dockTransition = Duration(milliseconds: 450);
  // トラック下辺から「つぎへ」ボタンまでの見た目上の距離。
  static const _dockDistance = 58.0;

  late final Ticker _ticker;
  late final AnimationController _dock;
  late final AnimationController _react;
  Duration _lastElapsed = Duration.zero;
  double _walkT = 0; // 0..1、トラック1周のうちどこにいるか
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _dock = AnimationController(vsync: this, duration: _dockTransition);
    _dock.addStatusListener(_onDockStatusChanged);
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _ticker = createTicker(_onTick)..start();
  }

  double get _perimeter =>
      2 * (widget.trackSize.width + widget.trackSize.height);

  /// 下辺中央(ボタンの直上)にあたるトラック一周のうちの位置(0..1)。
  double get _dockT {
    final w = widget.trackSize.width;
    final h = widget.trackSize.height;
    return (w + h + w / 2) / _perimeter;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    // ドック(ボタンの位置)へ向かう/留まる間は、通常の周回移動を止める。
    if (dt <= 0 || _dock.status != AnimationStatus.dismissed) return;

    final perimeter = _perimeter;
    final dockD = _dockT * perimeter;
    final oldD = _walkT * perimeter;
    final newT = (_walkT + dt / _walkSeconds) % 1.0;
    final newD = newT * perimeter;
    final reachedDock = widget.waiting && oldD < dockD && newD >= dockD;

    setState(() {
      if (reachedDock) {
        _walkT = _dockT; // ボタンの真上にぴったり揃えてから、ぶつかって止まる。
        _dock.forward(from: 0);
      } else {
        _walkT = newT;
      }
    });
  }

  void _onDockStatusChanged(AnimationStatus status) {
    // 到着した時点でもう「つぎへ」が押されていたら、待たずにすぐ引き返す。
    if (status == AnimationStatus.completed && !widget.waiting) {
      _dock.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant CatMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.waiting &&
        oldWidget.waiting &&
        _dock.status == AnimationStatus.completed) {
      _dock.reverse();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _dock.dispose();
    _react.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_react.isAnimating) return;
    HapticFeedback.lightImpact();
    // 実際の鳴き声音源はまだ用意していないため、タップ演出は触覚+吹き出しのみで表現している。
    _react.forward(from: 0).whenComplete(() => _react.reverse());
    setState(() => _showBubble = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showBubble = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.trackSize.width;
    final h = widget.trackSize.height;
    final perimeter = 2 * (w + h);
    final size = widget.catSize;

    return AnimatedBuilder(
      animation: Listenable.merge([_dock, _react]),
      builder: (context, _) {
        final t = _walkT;
        final d = t * perimeter;
        double x, y;
        bool facingRight;
        if (d < w) {
          x = d;
          y = 0;
          facingRight = true;
        } else if (d < w + h) {
          x = w;
          y = d - w;
          facingRight = true;
        } else if (d < 2 * w + h) {
          x = w - (d - w - h);
          y = h;
          facingRight = false;
        } else {
          x = 0;
          y = h - (d - 2 * w - h);
          facingRight = false;
        }

        final hugAmount = _dock.value;
        // ドックに向かうほど、下辺からボタンの位置までまっすぐ降りていく。
        y += _dockDistance * hugAmount;

        final tailWag = math.sin(t * 2 * math.pi * 14);
        final bob = math.sin(t * 2 * math.pi * 20).abs() * (1 - hugAmount);
        final bounce = Curves.elasticOut.transform(_react.value);

        return Positioned(
          left: x - size / 2,
          top: y - size / 2 - bob * 3,
          // 抱きついている間は「つぎへ」ボタンの上に重なるため、タップを透過させて
          // ボタン自体は押せる状態を保つ。
          child: IgnorePointer(
            ignoring: hugAmount > 0.5,
            child: GestureDetector(
              onTap: _onTap,
              child: SizedBox(
                width: size,
                height: size + 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (_showBubble)
                      Positioned(top: -20, child: _SpeechBubble()),
                    Transform.scale(
                      scaleY: 1 - bounce * 0.18,
                      scaleX: 1 + bounce * 0.14,
                      alignment: Alignment.bottomCenter,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                            facingRight ? 1.0 : -1.0,
                            1.0,
                            1.0,
                            1.0,
                          ),
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'ニャー!',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: nekoOrange,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// 猫が身につけられる小物。IDは`ProgressRepository`の実績IDと対応させている。
enum CatAccessory {
  none,
  ribbon,
  crown,
  sunglasses,
  scarf;

  static CatAccessory fromId(String? id) {
    if (id == null) return CatAccessory.none;
    return CatAccessory.values.firstWhere(
      (a) => a.name == id,
      orElse: () => CatAccessory.none,
    );
  }
}

class CatPainter extends CustomPainter {
  CatPainter({
    required this.tailWag,
    this.hugAmount = 0,
    this.accessory = CatAccessory.none,
  });

  final double tailWag;

  /// 0=通常の歩行ポーズ、1=枠に抱きついているポーズ。
  final double hugAmount;

  final CatAccessory accessory;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = nekoOrange;
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = inkBrown;
    final pink = Paint()..color = const Color(0xFFF3AFAF);

    // 尻尾
    final tailBase = Offset(w * 0.18, h * 0.6);
    final tailTip = Offset(
      w * 0.18 - w * 0.3,
      h * 0.6 - h * 0.22 * tailWag - h * 0.08,
    );
    final tailPath = Path()
      ..moveTo(tailBase.dx, tailBase.dy)
      ..quadraticBezierTo(
        tailBase.dx - w * 0.26,
        tailBase.dy - h * 0.05,
        tailTip.dx,
        tailTip.dy,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = nekoOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeCap = StrokeCap.round,
    );

    // 胴体
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.55, h * 0.68),
        width: w * 0.62,
        height: h * 0.4,
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.55, h * 0.74),
        width: w * 0.32,
        height: h * 0.22,
      ),
      white,
    );

    // 足
    for (final dx in [-0.15, 0.15]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.55 + w * dx, h * 0.88),
          width: w * 0.14,
          height: h * 0.08,
        ),
        body,
      );
    }

    // 抱きつく腕(体の後ろに描いて、後で顔などが重なるようにする)
    if (hugAmount > 0.01) {
      _drawHugArms(canvas, w, h, hugAmount);
    }

    // 頭
    final headCenter = Offset(w * 0.55, h * 0.36);
    final headRadius = w * 0.32;
    canvas.drawCircle(headCenter, headRadius, body);

    // 耳
    final earL = _earPath(headCenter, headRadius, left: true);
    final earR = _earPath(headCenter, headRadius, left: false);
    canvas.drawPath(earL, body);
    canvas.drawPath(earR, body);
    canvas.drawPath(_scalePath(earL, headCenter, 0.55), pink);
    canvas.drawPath(_scalePath(earR, headCenter, 0.55), pink);

    // 頭に乗せるアクセサリー(リボン・王冠)
    if (accessory == CatAccessory.ribbon) {
      _drawRibbon(canvas, headCenter, headRadius, w, h);
    } else if (accessory == CatAccessory.crown) {
      _drawCrown(canvas, headCenter, headRadius, w, h);
    }

    // 目: サングラス装着時は目を隠して描画、抱きついている時は嬉しそうに閉じる
    if (accessory == CatAccessory.sunglasses) {
      _drawSunglasses(canvas, headCenter, headRadius, w, h);
    } else if (hugAmount > 0.5) {
      _drawHappyEyes(canvas, headCenter, headRadius, w, h, dark.color);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx - headRadius * 0.32, headCenter.dy),
          width: w * 0.07,
          height: h * 0.07,
        ),
        dark,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx + headRadius * 0.32, headCenter.dy),
          width: w * 0.07,
          height: h * 0.07,
        ),
        dark,
      );
    }

    // 鼻
    final nose = Path()
      ..moveTo(headCenter.dx - w * 0.03, headCenter.dy + headRadius * 0.28)
      ..lineTo(headCenter.dx + w * 0.03, headCenter.dy + headRadius * 0.28)
      ..lineTo(headCenter.dx, headCenter.dy + headRadius * 0.4)
      ..close();
    canvas.drawPath(nose, pink);

    // ひげ
    final whisker = Paint()
      ..color = inkBrown.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (final dy in [-0.06, 0.0, 0.06]) {
      canvas.drawLine(
        Offset(
          headCenter.dx - headRadius * 0.5,
          headCenter.dy + headRadius * (0.3 + dy),
        ),
        Offset(
          headCenter.dx - headRadius * 1.15,
          headCenter.dy + headRadius * (0.2 + dy),
        ),
        whisker,
      );
      canvas.drawLine(
        Offset(
          headCenter.dx + headRadius * 0.5,
          headCenter.dy + headRadius * (0.3 + dy),
        ),
        Offset(
          headCenter.dx + headRadius * 1.15,
          headCenter.dy + headRadius * (0.2 + dy),
        ),
        whisker,
      );
    }

    // マフラー(首元。顔の上に重ねて描き、首に巻いているように見せる)
    if (accessory == CatAccessory.scarf) {
      _drawScarf(canvas, w, h);
    }

    // 抱きついている時だけ現れるハート
    if (hugAmount > 0.4) {
      _drawHeart(canvas, w, h, ((hugAmount - 0.4) / 0.6).clamp(0, 1));
    }
  }

  void _drawHugArms(Canvas canvas, double w, double h, double amount) {
    // 体と同色だと重なって見えなくなるため、先に太めの縁取りを描いてから
    // 本体色を重ね、腕の輪郭が体に埋もれないようにする。
    final outlinePaint = Paint()
      ..color = inkBrown.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09 + 3
      ..strokeCap = StrokeCap.round;
    final armPaint = Paint()
      ..color = nekoOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final start = Offset(w * 0.55 + side * w * 0.28, h * 0.56);
      final control = Offset(w * 0.55 + side * w * 0.42 * amount, h * 0.75);
      final end = Offset(
        w * 0.55 + side * w * 0.05 * (1 - amount),
        h * (0.86 + 0.04 * amount),
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(path, armPaint);
    }
  }

  void _drawHappyEyes(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    double w,
    double h,
    Color color,
  ) {
    final eyePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final cx = headCenter.dx + side * headRadius * 0.32;
      final cy = headCenter.dy;
      final path = Path()
        ..moveTo(cx - w * 0.035, cy + h * 0.02)
        ..quadraticBezierTo(cx, cy - h * 0.03, cx + w * 0.035, cy + h * 0.02);
      canvas.drawPath(path, eyePaint);
    }
  }

  void _drawHeart(Canvas canvas, double w, double h, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFFEF6C8E).withValues(alpha: opacity);
    final cx = w * 0.55;
    final cy = h * 0.04;
    final r = w * 0.07;
    final path = Path()
      ..moveTo(cx, cy + r * 0.7)
      ..cubicTo(
        cx - r * 1.3,
        cy - r * 0.5,
        cx - r * 0.4,
        cy - r * 1.3,
        cx,
        cy - r * 0.3,
      )
      ..cubicTo(
        cx + r * 0.4,
        cy - r * 1.3,
        cx + r * 1.3,
        cy - r * 0.5,
        cx,
        cy + r * 0.7,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawRibbon(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    double w,
    double h,
  ) {
    final ribbonPaint = Paint()..color = const Color(0xFFEF6C8E);
    final knotPaint = Paint()..color = const Color(0xFFD1467A);
    final cx = headCenter.dx;
    final cy = headCenter.dy - headRadius * 1.05;
    final wingW = w * 0.09;
    final wingH = h * 0.07;
    final leftWing = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - wingW, cy - wingH * 0.6)
      ..lineTo(cx - wingW * 0.9, cy + wingH * 0.7)
      ..close();
    final rightWing = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + wingW, cy - wingH * 0.6)
      ..lineTo(cx + wingW * 0.9, cy + wingH * 0.7)
      ..close();
    canvas.drawPath(leftWing, ribbonPaint);
    canvas.drawPath(rightWing, ribbonPaint);
    canvas.drawCircle(Offset(cx, cy), w * 0.03, knotPaint);
  }

  void _drawCrown(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    double w,
    double h,
  ) {
    final gold = Paint()..color = const Color(0xFFF2B84B);
    final jewel = Paint()..color = const Color(0xFFEF6C8E);
    final cx = headCenter.dx;
    final baseY = headCenter.dy - headRadius * 1.15;
    final crownW = w * 0.34;
    final crownH = h * 0.11;
    final path = Path()
      ..moveTo(cx - crownW / 2, baseY + crownH)
      ..lineTo(cx - crownW / 2, baseY)
      ..lineTo(cx - crownW / 4, baseY + crownH * 0.5)
      ..lineTo(cx, baseY - crownH * 0.2)
      ..lineTo(cx + crownW / 4, baseY + crownH * 0.5)
      ..lineTo(cx + crownW / 2, baseY)
      ..lineTo(cx + crownW / 2, baseY + crownH)
      ..close();
    canvas.drawPath(path, gold);
    canvas.drawCircle(Offset(cx, baseY + crownH * 0.6), w * 0.02, jewel);
  }

  void _drawSunglasses(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    double w,
    double h,
  ) {
    final lens = Paint()..color = inkBrown;
    final bridge = Paint()
      ..color = inkBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    final leftCenter = Offset(headCenter.dx - headRadius * 0.32, headCenter.dy);
    final rightCenter = Offset(headCenter.dx + headRadius * 0.32, headCenter.dy);
    const lensWidth = 0.16;
    const lensHeight = 0.1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: leftCenter,
          width: w * lensWidth,
          height: h * lensHeight,
        ),
        Radius.circular(w * 0.03),
      ),
      lens,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rightCenter,
          width: w * lensWidth,
          height: h * lensHeight,
        ),
        Radius.circular(w * 0.03),
      ),
      lens,
    );
    canvas.drawLine(
      Offset(leftCenter.dx + w * lensWidth / 2, leftCenter.dy),
      Offset(rightCenter.dx - w * lensWidth / 2, rightCenter.dy),
      bridge,
    );
  }

  void _drawScarf(Canvas canvas, double w, double h) {
    final scarfPaint = Paint()..color = const Color(0xFF5B8FD1);
    final band = Rect.fromCenter(
      center: Offset(w * 0.55, h * 0.62),
      width: w * 0.56,
      height: h * 0.09,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(h * 0.045)),
      scarfPaint,
    );
    final tail = Rect.fromCenter(
      center: Offset(w * 0.7, h * 0.72),
      width: w * 0.11,
      height: h * 0.15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tail, Radius.circular(w * 0.03)),
      scarfPaint,
    );
  }

  Path _earPath(Offset headCenter, double headRadius, {required bool left}) {
    final sign = left ? -1.0 : 1.0;
    return Path()
      ..moveTo(
        headCenter.dx + sign * headRadius * 0.7,
        headCenter.dy - headRadius * 0.5,
      )
      ..lineTo(
        headCenter.dx + sign * headRadius * 1.05,
        headCenter.dy - headRadius * 1.5,
      )
      ..lineTo(
        headCenter.dx + sign * headRadius * 0.05,
        headCenter.dy - headRadius * 0.95,
      )
      ..close();
  }

  Path _scalePath(Path path, Offset center, double scale) {
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    return path.transform(matrix.storage);
  }

  @override
  bool shouldRepaint(covariant CatPainter oldDelegate) =>
      oldDelegate.tailWag != tailWag ||
      oldDelegate.hugAmount != hugAmount ||
      oldDelegate.accessory != accessory;
}
