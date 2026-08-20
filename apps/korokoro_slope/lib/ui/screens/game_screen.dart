import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../game/game_bridge.dart';

/// three.js製ゲーム本体(assets/web/)をWebViewでホストする唯一の画面。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    if (kDebugMode && !kIsWeb && Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(true);
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFBFE8FF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _loadError = true);
            }
          },
        ),
      );
    GameBridge(controller: _controller).attach();
    _controller.loadFlutterAsset('assets/web/index.html');
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _handleBack(bool didPop) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        backgroundColor: const Color(0xFFBFE8FF),
        body: SafeArea(
          child: _loadError ? _LoadErrorView(onRetry: _retry) : WebViewWidget(controller: _controller),
        ),
      ),
    );
  }

  void _retry() {
    setState(() => _loadError = false);
    _controller.loadFlutterAsset('assets/web/index.html');
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('読み込みに失敗しました', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}
