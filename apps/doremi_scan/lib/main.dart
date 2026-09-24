import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/engine/cloud_omr_engine.dart';
import 'src/engine/doremi_engine.dart';
import 'src/engine/mock_doremi_engine.dart';
import 'src/engine/native_doremi_engine.dart';
import 'src/screens/home_screen.dart';
import 'src/theme/app_theme.dart';

void main() {
  runApp(const DoremiScanApp());
}

class DoremiScanApp extends StatelessWidget {
  const DoremiScanApp({super.key});

  /// エンジン選択:
  /// - クラウドOMR(Audiveris on Cloud Run)のURLが注入されていれば最優先（無料・複雑譜対応）
  /// - iOS実機ならオンデバイス Core ML（フォールバック）
  /// - モックは開発ビルド限定。リリースでモックに落ちると
  ///   「どんな写真にも偽の結果を返すアプリ」になるため、明示エラーにする
  DoremiEngine _selectEngine() {
    const hasCloud = bool.hasEnvironment('OMR_API_URL') &&
        String.fromEnvironment('OMR_API_URL') != '';
    if (hasCloud) return CloudOmrEngine();
    if (!kIsWeb && Platform.isIOS) return NativeDoremiEngine();
    assert(() {
      return true; // デバッグではモックを許可（UI開発用）
    }());
    if (kReleaseMode) {
      throw StateError(
          'リリースビルドに OMR_API_URL が注入されていません（--dart-define を確認）');
    }
    return MockDoremiEngine();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ドレミふりがな',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(engine: _selectEngine()),
    );
  }
}
