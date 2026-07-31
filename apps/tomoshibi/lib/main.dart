import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
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
  Map<String, String> _attHeaders = const {};
  bool _skipNextLogoutIntercept = false;
  // ログイン/ログアウトの連打でASWebAuthenticationSessionが多重起動されるのを防ぐ
  // (多重起動はACQUIRE_ROOT_VIEW_CONTROLLER_FAILED等の不安定な失敗の原因になる)。
  bool _authFlowBusy = false;

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
      );
    unawaited(_bootstrap());
    _initUniversalLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Guideline 5.1.2(i)対応: サイト側でトラッキングCookie(GA/AdSense)を使うため、
  /// WebViewが何かを読み込む前にATT許諾を確認する。結果はX-ATT-Statusヘッダとして
  /// 以降のすべての実ページ読み込みに載せ、サイト側(gikyoku_tosyokan)がdenied時に
  /// トラッキング系スクリプトを止められるようにする。
  Future<void> _bootstrap() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;

    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    _attHeaders = {
      'X-ATT-Status': status == TrackingStatus.authorized ? 'authorized' : 'denied',
    };
    await _controller.loadRequest(Uri.parse(_homeUrl), headers: _attHeaders);
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
      _controller.loadRequest(uri, headers: _attHeaders);
    }
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.parse(request.url);
    final host = uri.host;
    // 新規Pro購入 (Stripe Checkout) はApp Store審査 3.1.1 によりネイティブIAPに
    // 置き換える。既存Web購読者の解約・支払い方法変更 (billing.stripe.com) は
    // 新規購入ではないので isInAppHost 側でそのまま許可する。
    if (host == stripeCheckoutHost) {
      unawaited(_startNativePurchase());
      return NavigationDecision.prevent;
    }
    // サインイン導線はWebView埋め込みではなくASWebAuthenticationSessionで開く
    // (Guideline 4対応、navigation_policy.dartのコメント参照)。
    if (isAuthSignInRequest(uri)) {
      if (_authFlowBusy) return NavigationDecision.prevent;
      _authFlowBusy = true;
      unawaited(_startWebAuth(uri).whenComplete(() => _authFlowBusy = false));
      return NavigationDecision.prevent;
    }
    if (isLogoutRequest(uri)) {
      // _startLogout自身が最後にこの同じURLをWebViewへ読み込むため、
      // その2回目はここで再度横取りせずそのまま通す(でないと無限ループする)。
      if (_skipNextLogoutIntercept) {
        _skipNextLogoutIntercept = false;
        return NavigationDecision.navigate;
      }
      if (_authFlowBusy) return NavigationDecision.prevent;
      _authFlowBusy = true;
      unawaited(_startLogout(uri).whenComplete(() => _authFlowBusy = false));
      return NavigationDecision.prevent;
    }
    if (isInAppHost(host)) {
      return NavigationDecision.navigate;
    }
    await launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  Future<void> _startWebAuth(Uri signInUri) async {
    final authUri = signInUri.replace(
      queryParameters: {
        ...signInUri.queryParameters,
        'callbackUrl': authCallbackUrl,
      },
    );
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: authCallbackUrlScheme,
      );
      // ASWebAuthenticationSessionとアプリ本体のWebViewはCookieストアが別なので、
      // サインインをそのまま完了しても本体WebViewにはセッションが引き継がれない。
      // gikyoku_tosyokan側が発行した使い捨てトークンでmobile-handoffを叩かせ、
      // そのレスポンスとして本体WebView自身のCookieストアにセッションを発行させる。
      final token = Uri.parse(result).queryParameters['token'];
      final target = token == null
          ? Uri.parse(_homeUrl)
          : Uri.https('gikyokutosyokan.com', '/api/auth/mobile-handoff', {
              'token': token,
            });
      await _controller.loadRequest(target, headers: _attHeaders);
    } on PlatformException catch (e) {
      // "CANCELED" はユーザーが自分でシートを閉じた場合のみ。
      // それ以外(ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED 等)は本物のエラーなので表示する。
      if (e.code != 'CANCELED') {
        _showMessage('サインインに失敗しました: [${e.code}] ${e.message}');
      }
    } catch (e) {
      _showMessage('サインインに失敗しました: $e');
    }
  }

  /// ログアウトはアプリ本体WebViewのCookieストアだけでなく、
  /// ASWebAuthenticationSessionの共有Cookieストア側のセッションも消す必要がある
  /// (navigation_policy.dart の isLogoutRequest 参照)。
  Future<void> _startLogout(Uri logoutUri) async {
    final sharedLogoutUri = logoutUri.replace(
      queryParameters: {
        ...logoutUri.queryParameters,
        'callbackUrl': authCallbackUrl,
      },
    );
    try {
      await FlutterWebAuth2.authenticate(
        url: sharedLogoutUri.toString(),
        callbackUrlScheme: authCallbackUrlScheme,
      );
    } catch (_) {
      // 共有Cookieストア側のクリアに失敗しても、アプリ本体側のログアウトは続行する。
    }
    _skipNextLogoutIntercept = true;
    // アプリ本体WebView側のCookieは元のcallbackUrl(通常はホーム)への遷移で消す。
    await _controller.loadRequest(logoutUri, headers: _attHeaders);
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
              // ATT許諾待ち〜初回ページ読み込み開始前は_progressが0のままなので、
              // 画面が固まって見えないよう全画面のローディング表示で覆う。
              if (_progress == 0 && _loadError == null) const _LaunchLoadingOverlay(),
              if (_purchaseBusy) const _BusyOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchLoadingOverlay extends StatelessWidget {
  const _LaunchLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07060A),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFC8482D)),
          const SizedBox(height: 16),
          Text(
            'TOMOSHIBI小屋',
            style: TextStyle(
              color: const Color(0xFFF0E8DA).withValues(alpha: 0.7),
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
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
