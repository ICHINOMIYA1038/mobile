// アプリアイコンを生成するワンショットスクリプト。
// `_CatPainter`(猫マスコットの見た目)をそのままアイコンにも使い回すことで、
// アプリ内の猫とアイコンの絵柄がズレないようにしている。
//
// 実行方法: flutter test tool/generate_icons.dart
// 生成物: icon/icon.png (iOS/通常アイコン、背景あり)
//         icon/icon_foreground.png (Android adaptive icon前景、透過)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neko_chemistry/ui/theme.dart';
import 'package:neko_chemistry/ui/widgets/cat_mascot.dart';

const _canvasSize = 1024.0;

void main() {
  testWidgets('generate app icons', (tester) async {
    await tester.runAsync(() async {
      await _capture(
        tester,
        path: 'icon/icon.png',
        background: nekoCream,
        // 猫の描画は尻尾・耳がCustomPaintの公称サイズより外側にはみ出すため、
        // 1024角のキャンバスで欠けないよう700程度に抑えている。
        catSize: 700,
      );
      await _capture(
        tester,
        path: 'icon/icon_foreground.png',
        background: Colors.transparent,
        catSize: 640,
      );
    });
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required String path,
  required Color background,
  required double catSize,
}) async {
  final key = GlobalKey();

  tester.view.physicalSize = const Size(_canvasSize, _canvasSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Container(
          width: _canvasSize,
          height: _canvasSize,
          color: background,
          child: Center(
            child: CustomPaint(
              size: Size(catSize, catSize),
              painter: CatPainter(tailWag: 0.6),
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
