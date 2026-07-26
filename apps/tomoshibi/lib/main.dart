import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'navigation_policy.dart';
import 'purchase_service.dart';

const _homeUrl = 'https://tomoshibi.gikyokutosyokan.com/';

void main() {
  runApp(const TomoshibiApp());
}

class TomoshibiApp extends StatelessWidget {
  const TomoshibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOMOSHIBI小屋',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8482D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07060A),
      ),
      home: const TomoshibiWebView(),
    );
  }
}

class TomoshibiWebView extends StatefulWidget {
  const TomoshibiWebView({super.key});

  @override
  State<TomoshibiWebView> createState() => _TomoshibiWebViewState();
}

class _TomoshibiWebViewState extends State<TomoshibiWebView> {
  late final WebViewController _controller;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  double _progress = 0;
  String? _loadError;
  bool _purchaseBusy = false;
  Completer<String?>? _sessionCompleter;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF07060A))
      ..addJavaScriptChannel(
        'TomoshibiSession',
        onMessageReceived: (message) {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          _sessionCompleter?.complete(data['userId'] as String?);
          _sessionCompleter = null;
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress / 100),
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _loadError = error.description);
            }
          },
          onPageStarted: (_) => setState(() => _loadError = null),
        ),
      )
      ..loadRequest(Uri.parse(_homeUrl));
    _initUniversalLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Universal Links (共有URL・戯曲図書館からのリンク等) をタップしてアプリが
  /// 開かれた場合、Safariではなくこのアプリ内のWebViewでそのURLを直接開く。
  Future<void> _initUniversalLinks() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _openUniversalLink(initialUri);
    _linkSubscription = _appLinks.uriLinkStream.listen(_openUniversalLink);
  }

  void _openUniversalLink(Uri uri) {
    if (uri.host.endsWith('tomoshibi.gikyokutosyokan.com')) {
      _controller.loadRequest(uri);
    }
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final host = Uri.parse(request.url).host;
    // 新規Pro購入 (Stripe Checkout) はApp Store審査 3.1.1 によりネイティブIAPに
    // 置き換える。既存Web購読者の解約・支払い方法変更 (billing.stripe.com) は
    // 新規購入ではないので isInAppHost 側でそのまま許可する。
    if (host == stripeCheckoutHost) {
      unawaited(_startNativePurchase());
      return NavigationDecision.prevent;
    }
    if (isInAppHost(host)) {
      return NavigationDecision.navigate;
    }
    await launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  /// tomoshibi Webセッションから戯曲図書館のユーザーIDを取得する。未ログインなら null。
  Future<String?> _fetchSessionUserId() async {
    final completer = Completer<String?>();
    _sessionCompleter = completer;
    await _controller.runJavaScript('''
      fetch('/api/tomoshibi/session', { credentials: 'include' })
        .then(r => r.json())
        .then(d => TomoshibiSession.postMessage(JSON.stringify({ userId: d.user ? d.user.id : null })))
        .catch(e => TomoshibiSession.postMessage(JSON.stringify({ userId: null })));
    ''');
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  Future<void> _startNativePurchase() async {
    setState(() => _purchaseBusy = true);
    try {
      final userId = await _fetchSessionUserId();
      if (userId == null) {
        _showMessage('購入するにはログインが必要です');
        return;
      }
      await PurchaseService.purchasePro(userId);
      _showMessage('ご購入ありがとうございます。Pro プランが有効になりました');
      await _controller.reload();
    } on PurchaseCancelledException {
      // ユーザーがキャンセルしただけなので何もしない。
    } catch (e) {
      _showMessage('購入処理でエラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _purchaseBusy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 1 && _loadError == null)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFFC8482D),
                ),
              if (_loadError != null)
                _ErrorOverlay(
                  message: _loadError!,
                  onRetry: () {
                    setState(() => _loadError = null);
                    _controller.reload();
                  },
                ),
              if (_purchaseBusy) const _BusyOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: Color(0xFFC8482D)),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07060A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '読み込みに失敗しました',
            style: TextStyle(color: Color(0xFFF0E8DA), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF0E8DA), fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
        ],
      ),
    );
  }
}
