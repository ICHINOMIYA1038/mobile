// アプリアイコンを生成するワンショットスクリプト。
// アナログ騒音計を模した`LevelGauge`(lib/ui/widgets/level_gauge.dart)を
// そのままアイコンにも使い回すことで、アプリ内のゲージとアイコンの絵柄を
// 揃えている。
//
// 実行方法: flutter test tool/generate_icons.dart
// 生成物: icon/icon.png (iOS/通常アイコン、背景あり)
//         icon/icon_foreground.png (Android adaptive icon前景、透過)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_shield/ui/widgets/level_gauge.dart';

const _canvasSize = 1024.0;
// 「計測中」を思わせる、針が右上寄りに傾いた見た目にする。
const _level = 0.62;

void main() {
  testWidgets('generate app icons', (tester) async {
    await tester.runAsync(() async {
      await _capture(
        tester,
        path: 'icon/icon.png',
        background: const Color(0xFFEFEAE0), // paper
        gaugeSize: 900,
      );
      await _capture(
        tester,
        path: 'icon/icon_foreground.png',
        background: Colors.transparent,
        gaugeSize: 820,
      );
    });
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required String path,
  required Color background,
  required double gaugeSize,
}) async {
  final key = GlobalKey();

  tester.view.physicalSize = const Size(_canvasSize, _canvasSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: RepaintBoundary(
        key: key,
        child: Container(
          width: _canvasSize,
          height: _canvasSize,
          color: background,
          // LevelGaugeは-210°〜30°の弧（上半分＋左右の裾のみ）を描くため、
          // 視覚的な内容はウィジェットの上寄りに偏っている。単純にCenterで
          // 置くと絵の重心がキャンバス中心より上に来て、下側が間延びして
          // 見える。視覚的な内容の実バウンディングボックス（tick外周半径
          // r=size*0.42を基準に、上端≈center-r、左右の裾≈center+r*0.5）の
          // 中心がキャンバス中心に来るよう、下に約r*0.105ずらす。
          child: Center(
            child: Transform.translate(
              offset: Offset(0, gaugeSize * 0.19),
              child: LevelGauge(level: _level, size: gaugeSize),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).create(recursive: true);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${image.width}x${image.height})');
}
