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

class _TomoshibiWebViewState extends State<TomoshibiWebView>
    with WidgetsBindingObserver {
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
  Completer<void>? _resumedCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumedCompleter?.complete();
    }
  }

  /// ATT許諾ダイアログは、ウィンドウが実際にkeyウィンドウ(resumed)になって
  /// いない状態でリクエストすると、OSがダイアログを出さずに黙って未許諾扱いに
  /// することがある(特にiPadのマルチタスク環境。iPadOS 26.6での審査指摘の原因)。
  /// 初回フレーム描画後、AppLifecycleStateがresumedになるのを待ってから
  /// リクエストすることでこれを防ぐ。
  Future<void> _waitUntilResumed() async {
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => frameCompleter.complete());
    await frameCompleter.future;

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _resumedCompleter = Completer<void>();
      await _resumedCompleter!.future;
    }
  }

  /// Guideline 5.1.2(i)対応: サイト側でトラッキングCookie(GA/AdSense)を使うため、
  /// WebViewが何かを読み込む前にATT許諾を確認する。結果はX-ATT-Statusヘッダとして
  /// 以降のすべての実ページ読み込みに載せ、サイト側(gikyoku_tosyokan)がdenied時に
  /// トラッキング系スクリプトを止められるようにする。
  Future<void> _bootstrap() async {
    await _waitUntilResumed();

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
    // 未ログイン状態でもアプリ内から購入できるようにするための専用スキーム。
    // navigation_policy.dartのisNativePurchaseRequestのコメント参照。
    if (isNativePurchaseRequest(uri)) {
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

  /// Guideline 5.1.1(v)対応: アカウントに紐付かない購入の前にサイトへの
  /// ログイン(会員登録)を必須にしてはならない。ログイン状態に関わらずまず
  /// 購入自体を進め(未ログインならRevenueCatの匿名IDのまま購入)、未ログインの
  /// 場合のみ購入完了後に「複数端末で使うために任意でサインインしますか」と
  /// 案内するだけに留める。
  Future<void> _startNativePurchase() async {
    setState(() => _purchaseBusy = true);
    try {
      final userId = await _fetchSessionUserId();
      await PurchaseService.purchasePro(gikyokutosyokanUserId: userId);
      _showMessage('ご購入ありがとうございます。Pro プランが有効になりました');
      if (userId == null) {
        await _offerOptionalSignInAfterPurchase();
      } else {
        await _controller.reload();
      }
    } on PurchaseCancelledException {
      // ユーザーがキャンセルしただけなので何もしない。
    } catch (e) {
      _showMessage('購入処理でエラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _purchaseBusy = false);
    }
  }

  /// 匿名購入の直後、複数端末でPro機能を使うための任意のサインインを案内する。
  /// あくまで任意で、後からいつでも行えるため、断ってもここでは何もしない。
  Future<void> _offerOptionalSignInAfterPurchase() async {
    if (!mounted) return;
    final wantsToSignIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('他の端末でも使いますか?'),
        content: const Text(
          'サインインすると、この購入を他の端末でも引き続きご利用いただけます。'
          '後からいつでもサインインできます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('後で'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('サインインする'),
          ),
        ],
      ),
    );
    if (wantsToSignIn != true) return;
    if (_authFlowBusy) return;
    _authFlowBusy = true;
    try {
      await _startWebAuth(buildAuthSignInUri());
    } finally {
      _authFlowBusy = false;
    }
    final newUserId = await _fetchSessionUserId();
    if (newUserId != null) {
      try {
        await PurchaseService.linkPurchaseToAccount(newUserId);
      } catch (_) {
        // リンクに失敗しても購入自体は既に有効なので致命的ではない。
      }
    }
    await _controller.reload();
  }

  /// Guideline 3.1.1対応: ユーザーが明示的にタップしたときのみ復元する
  /// (自動復元では審査要件を満たさない)。未ログインでもStoreKit側の復元は
  /// 必ず実行する(ログイン必須にすると復元操作自体が機能しなくなるため)。
  Future<void> _restorePurchases() async {
    setState(() => _purchaseBusy = true);
    try {
      final userId = await _fetchSessionUserId();
      final info = await PurchaseService.restorePurchases(
        gikyokutosyokanUserId: userId,
      );
      if (info.entitlements.active.isEmpty) {
        _showMessage('復元できる購入が見つかりませんでした');
      } else if (userId == null) {
        _showMessage('購入を復元しました。反映するにはログインしてください');
      } else {
        _showMessage('購入を復元しました');
        await _controller.reload();
      }
    } catch (e) {
      _showMessage('購入の復元に失敗しました: $e');
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
              if (_progress > 0 && !_purchaseBusy)
                _RestorePurchasesButton(onPressed: _restorePurchases),
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

class _RestorePurchasesButton extends StatelessWidget {
  const _RestorePurchasesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // サイト側のヘッダーやフッター (右上のユーザーアバター、右下のシーン編集
    // メニュー等) と衝突しないよう、常に空いている左下隅にアイコンのみで置く。
    return Positioned(
      bottom: 8,
      left: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: Tooltip(
          message: '購入を復元',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.restore, size: 18, color: Color(0xFFF0E8DA)),
            ),
          ),
        ),
      ),
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
