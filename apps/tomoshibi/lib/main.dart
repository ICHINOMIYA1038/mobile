import 'dart:async';
import 'dart:convert';

import 'package:app_insights/app_insights.dart';
import 'package:app_links/app_links.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'ad_service.dart';
import 'firebase_options.dart';
import 'navigation_policy.dart';
import 'purchase_service.dart';

const _homeUrl = 'https://tomoshibi.gikyokutosyokan.com/studio/projects/';
const _sessionApiUrl = 'https://gikyokutosyokan.com/api/tomoshibi/session';
// アプリで買った Pro を、Webhook を待たずにアカウントへ反映させる（サーバーが RevenueCat から取り直す）
const _appStoreSyncUrl = 'https://gikyokutosyokan.com/api/tomoshibi/revenuecat-sync';

/// Web のセッションの確かめの結果。ok が false なら、通信の失敗などで確かめられなかった（ログインしていないとは限らない）
class _SessionInfo {
  const _SessionInfo({required this.ok, this.userId, this.isPro = false});
  final bool ok;
  final String? userId;
  final bool isPro;
}

/// 起動時に開くURL。既定は本番のプロジェクト一覧。
/// ストア用スクリーンショットの撮影 (tool/screenshots.sh) から、シーンを
/// 埋め込んだ `#scene=...` 付きURLを流し込むための差し替え口。
/// リリースビルドではこのdefineを渡さないので常に _homeUrl になる。
const _startUrl = String.fromEnvironment(
  'TOMOSHIBI_START_URL',
  defaultValue: _homeUrl,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TomoshibiApp());
}

class TomoshibiApp extends StatelessWidget {
  const TomoshibiApp({
    super.key,
    this.startUrl = _startUrl,
    this.requestTracking = true,
  });

  /// 最初に開くURL。既定は `--dart-define=TOMOSHIBI_START_URL` かプロジェクト一覧。
  final String startUrl;

  /// ATT許諾をリクエストするか。スクリーンショット撮影時のみfalseにして、
  /// OSの許諾ダイアログが画面に被らないようにする。
  final bool requestTracking;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOMOSHIBI小屋',
      debugShowCheckedModeBanner: false,
      navigatorObservers: AppInsights.navigatorObservers,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8482D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07060A),
      ),
      home: TomoshibiWebView(
        startUrl: startUrl,
        requestTracking: requestTracking,
      ),
    );
  }
}

class TomoshibiWebView extends StatefulWidget {
  const TomoshibiWebView({
    super.key,
    this.startUrl = _startUrl,
    this.requestTracking = true,
  });

  final String startUrl;
  final bool requestTracking;

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
  // 画面の下のバナー広告。Web が「出してよい」と知らせ（無料の人）、アプリで Pro を買っていないときだけ出す
  bool _adsAllowedByWeb = false;
  bool _hasNativePro = false;
  bool _trackingAuthorized = false;
  BannerAd? _banner;
  bool _bannerLoading = false;
  Completer<_SessionInfo>? _sessionCompleter;
  Map<String, String> _attHeaders = const {};
  bool _skipNextLogoutIntercept = false;
  // ログイン/ログアウトの連打でASWebAuthenticationSessionが多重起動されるのを防ぐ
  // (多重起動はACQUIRE_ROOT_VIEW_CONTROLLER_FAILED等の不安定な失敗の原因になる)。
  bool _authFlowBusy = false;
  Completer<void>? _resumedCompleter;
  // ATT許諾が終わって最初のページを読み込むまでは _attHeaders が確定しないため、
  // その間に届いたUniversal Link(コールドスタート時の起動URL等)はここに溜めて
  // _bootstrap 側で開く。溜めずに即 loadRequest すると、直後の _bootstrap が
  // ホームを読み込んで上書きし、共有URLで開いたはずのシーンが消える。
  Uri? _pendingUniversalLink;
  bool _bootstrapped = false;
  // loadRequest したページの onPageFinished を待つための口。
  Completer<void>? _pageFinishedCompleter;

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
          final completer = _sessionCompleter;
          _sessionCompleter = null;
          // タイムアウト後に遅れて届いた応答で二重completeしないようにする。
          if (completer != null && !completer.isCompleted) {
            completer.complete(_SessionInfo(
              ok: data['ok'] != false,
              userId: data['userId'] as String?,
              isPro: data['plan'] == 'pro',
            ));
          }
        },
      )
      // Web から届く知らせ。いまは広告を出してよいか（{type: 'ads', show: bool}）だけ
      ..addJavaScriptChannel(
        'TomoshibiApp',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['type'] == 'ads') {
              _adsAllowedByWeb = data['show'] == true;
              unawaited(_syncBanner());
            }
          } catch (_) {
            // 形の違う知らせは無視する
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _loadError = error.description);
            }
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loadError = null);
          },
          onPageFinished: (_) {
            final completer = _pageFinishedCompleter;
            _pageFinishedCompleter = null;
            if (completer != null && !completer.isCompleted) {
              completer.complete();
            }
          },
        ),
      );
    // iOS の画面の端からのスワイプで前のページに戻れるようにする。アプリには戻るボタンが無く、
    // アカウント管理（戯曲図書館のマイページ）などに移ると TOMOSHIBI に戻れなかった（2026-11-14 オーナー報告）
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    unawaited(_bootstrap());
    _initUniversalLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _banner?.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => frameCompleter.complete(),
    );
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
    if (widget.requestTracking && status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    _trackingAuthorized = status == TrackingStatus.authorized;
    unawaited(_checkNativePro());
    _attHeaders = {
      'X-ATT-Status': status == TrackingStatus.authorized
          ? 'authorized'
          : 'denied',
    };
    _bootstrapped = true;
    // コールドスタート時にUniversal Linkで起動された場合はそのURLを優先する。
    final initial = _pendingUniversalLink ?? Uri.parse(widget.startUrl);
    _pendingUniversalLink = null;
    await _loadAndWaitFinished(initial);
    // 前回からログインしている人にも、RevenueCat の利用者を合わせる（以前の版で匿名のまま買った分を付ける）
    unawaited(_linkPurchasesToSignedInUser());
  }

  /// [uri] を読み込み、そのページの onPageFinished まで待つ。
  /// 読み込み完了を待たずに runJavaScript すると前のページ上で実行されてしまう
  /// (サインイン直後のセッション確認が未ログイン扱いになる原因)。
  Future<void> _loadAndWaitFinished(Uri uri) async {
    final completer = Completer<void>();
    _pageFinishedCompleter = completer;
    await _controller.loadRequest(uri, headers: _attHeaders);
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
  }

  /// Universal Links (共有URL・戯曲図書館からのリンク等) をタップしてアプリが
  /// 開かれた場合、Safariではなくこのアプリ内のWebViewでそのURLを直接開く。
  Future<void> _initUniversalLinks() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _openUniversalLink(initialUri);
    _linkSubscription = _appLinks.uriLinkStream.listen(_openUniversalLink);
  }

  void _openUniversalLink(Uri uri) {
    if (!isUniversalLinkHost(uri.host)) return;
    if (!_bootstrapped) {
      _pendingUniversalLink = uri;
      return;
    }
    _controller.loadRequest(uri, headers: _attHeaders);
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
    if (isRestorePurchasesRequest(uri)) {
      if (!_purchaseBusy) unawaited(_restorePurchases());
      return NavigationDecision.prevent;
    }
    if (isAuthSignInRequest(uri)) {
      if (_authFlowBusy) return NavigationDecision.prevent;
      _authFlowBusy = true;
      unawaited(_startWebAuth(uri).whenComplete(() => _authFlowBusy = false));
      return NavigationDecision.prevent;
    }
    if (isAccountPageRequest(uri)) {
      if (_authFlowBusy) return NavigationDecision.prevent;
      _authFlowBusy = true;
      unawaited(_openAccountPage(uri).whenComplete(() => _authFlowBusy = false));
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
    // ページ内の iframe（決済画面や広告の部品）の読み込みも、ここを通る。外で開くと、利用者が
    // 何も押していないのにブラウザが開いてアプリから離れてしまうので、ページの一部として読ませる。
    if (!request.isMainFrame) {
      return NavigationDecision.navigate;
    }
    // about:blank / blob: / data: 等はOSに渡しても開けず launchUrl が例外を投げる
    // (NavigationDelegate内の未捕捉例外はWebViewの操作不能につながる)。
    if (canOpenExternally(uri)) {
      try {
        await launchUrl(
          uri,
          mode: opensInAppBrowser(uri) && !opensInOtherApp(uri)
              ? LaunchMode.inAppBrowserView
              : LaunchMode.externalApplication,
        );
      } catch (_) {
        _showMessage('リンクを開けませんでした');
      }
    }
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
      await _loadAndWaitFinished(target);
      await _linkPurchasesToSignedInUser();
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

  /// 戯曲 ID のアカウント画面・退会画面をログインと同じシートで開く。そこでログアウトか退会をしたら、
  /// アプリの画面とシート側に残る戯曲図書館のセッションも消すため、ログアウトの流れを続けて行う。
  Future<void> _openAccountPage(Uri requested) async {
    final Uri returned;
    try {
      returned = Uri.parse(await FlutterWebAuth2.authenticate(
        url: buildAccountPageUri(requested).toString(),
        callbackUrlScheme: authCallbackUrlScheme,
      ));
    } on PlatformException catch (e) {
      // CANCELED はシートを閉じただけ
      if (e.code != 'CANCELED') {
        _showMessage('アカウントの画面を開けませんでした: [${e.code}] ${e.message}');
      }
      return;
    } catch (e) {
      _showMessage('アカウントの画面を開けませんでした: $e');
      return;
    }
    if (!needsLogoutAfterAccountPage(returned)) return;
    if (returned.queryParameters['result'] == 'deleted') {
      _showMessage('退会しました。ご利用ありがとうございました');
    }
    await _startLogout(
      Uri.https('gikyokutosyokan.com', '/api/tomoshibi/logout', {
        'callbackUrl': _homeUrl,
      }),
    );
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
    // RevenueCat の利用者も匿名に戻す。広告の判断も、この端末の匿名の購入だけで取り直す
    try {
      await PurchaseService.logOut();
    } catch (_) {
      // 次にログインしたときに合わせ直す
    }
    _hasNativePro = false;
    unawaited(_checkNativePro());
  }

  /// tomoshibi Webセッションを確かめる。通信の失敗・時間切れは ok: false（ログインしていない扱いにしない）
  Future<_SessionInfo> _fetchSession() async {
    final completer = Completer<_SessionInfo>();
    _sessionCompleter = completer;
    await _controller.runJavaScript('''
      fetch('$_sessionApiUrl', { credentials: 'include' })
        .then(r => r.json())
        .then(d => TomoshibiSession.postMessage(JSON.stringify({ ok: true, userId: d.user ? d.user.id : null, plan: d.user ? d.user.plan : null })))
        .catch(e => TomoshibiSession.postMessage(JSON.stringify({ ok: false })));
    ''');
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => const _SessionInfo(ok: false),
    );
  }

  /// アプリで買った Pro を、いまのアカウントへ反映するようサーバーに頼む（結果は待たない）。
  /// 匿名で買ってからログインした場合、RevenueCat は Webhook を送らないので、これで取り直す
  Future<void> _syncAppStoreToAccount() async {
    try {
      await _controller.runJavaScript('''
        fetch('$_appStoreSyncUrl', { method: 'POST', credentials: 'include', headers: { 'content-type': 'application/json' }, body: '{}' }).catch(() => {});
      ''');
    } catch (_) {
      // 反映は Webhook でも届くので、失敗しても止めない
    }
  }

  /// ログインしている人に、RevenueCat の利用者を合わせる。端末に Pro があれば、アカウントへの反映も頼む。
  /// 購入・復元のときだけ合わせていたので、ふつうにログインした人の匿名の購入がアカウントに付かなかった（2026-11-19 点検）
  Future<void> _linkPurchasesToSignedInUser() async {
    final session = await _fetchSession();
    final userId = session.userId;
    if (!session.ok || userId == null) return;
    try {
      await PurchaseService.linkPurchaseToAccount(userId);
      if (await PurchaseService.hasActivePro()) await _syncAppStoreToAccount();
    } catch (_) {
      // 次のログイン・購入・復元でもう一度合わせる
    }
  }

  /// Guideline 5.1.1(v)対応: アカウントに紐付かない購入の前にサイトへの
  /// ログイン(会員登録)を必須にしてはならない。ログイン状態に関わらずまず
  /// 購入自体を進め(未ログインならRevenueCatの匿名IDのまま購入)、未ログインの
  /// 場合のみ購入完了後に「複数端末で使うために任意でサインインしますか」と
  /// 案内するだけに留める。
  Future<void> _startNativePurchase() async {
    setState(() => _purchaseBusy = true);
    try {
      final session = await _fetchSession();
      // 確かめられないまま匿名で買わせると、ログインしている人の購入がアカウントに付かない（2026-11-19 点検）
      if (!session.ok) {
        _showMessage('通信を確かめられませんでした。接続を確認して、もう一度お試しください');
        return;
      }
      // Web（Stripe）などですでに Pro の人には、二重に買わせない
      if (session.isPro) {
        _showMessage('すでに Pro プランをご利用中です');
        return;
      }
      final userId = session.userId;
      await PurchaseService.purchasePro(gikyokutosyokanUserId: userId);
      _showMessage('ご購入ありがとうございます。Pro プランが有効になりました');
      _hasNativePro = true;
      unawaited(_syncBanner());
      if (userId == null) {
        await _offerOptionalSignInAfterPurchase();
      } else {
        await _syncAppStoreToAccount();
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
    // _startWebAuth のあとで、購入をアカウントに付けて反映まで頼んである
    await _controller.reload();
  }

  /// Guideline 3.1.1対応: ユーザーが明示的にタップしたときのみ復元する
  /// (自動復元では審査要件を満たさない)。未ログインでもStoreKit側の復元は
  /// 必ず実行する(ログイン必須にすると復元操作自体が機能しなくなるため)。
  Future<void> _restorePurchases() async {
    setState(() => _purchaseBusy = true);
    try {
      final session = await _fetchSession();
      final userId = session.ok ? session.userId : null;
      final info = await PurchaseService.restorePurchases(
        gikyokutosyokanUserId: userId,
      );
      if (info.entitlements.active.isNotEmpty) {
        _hasNativePro = true;
        unawaited(_syncBanner());
      }
      if (info.entitlements.active.isEmpty) {
        _showMessage('復元できる購入が見つかりませんでした');
      } else if (userId == null) {
        _showMessage('購入を復元しました。ほかの端末やアカウントへの保存で使うには、ログインしてください');
      } else {
        await _syncAppStoreToAccount();
        _showMessage('購入を復元しました');
        await _controller.reload();
      }
    } catch (e) {
      _showMessage('購入の復元に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _purchaseBusy = false);
    }
  }

  /// アプリで Pro を買ってある人には、Web の知らせを待たずに広告を出さない
  Future<void> _checkNativePro() async {
    try {
      _hasNativePro = await PurchaseService.hasActivePro();
    } catch (_) {
      // 確かめられなければ Web の知らせに任せる
    }
    unawaited(_syncBanner());
  }

  /// 出してよいならバナーを読み込み、出さないなら片付ける
  Future<void> _syncBanner() async {
    if (!mounted) return;
    final show = _adsAllowedByWeb && !_hasNativePro;
    if (!show) {
      final old = _banner;
      if (old != null) {
        setState(() => _banner = null);
        old.dispose();
      }
      return;
    }
    if (_banner != null || _bannerLoading) return;
    _bannerLoading = true;
    final ad = await AdService.loadBanner(personalized: _trackingAuthorized);
    _bannerLoading = false;
    if (!mounted || !(_adsAllowedByWeb && !_hasNativePro)) {
      ad?.dispose();
      return;
    }
    setState(() => _banner = ad);
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
          bottom: false,
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
              if (_progress == 0 && _loadError == null)
                const _LaunchLoadingOverlay(),
              if (_purchaseBusy) const _BusyOverlay(),
            ],
          ),
        ),
        // 下の帯はバナー広告（無料の人だけ）。「購入を復元」は Web の ⋯ メニューと Pro のページに移した（2026-11-18）
        bottomNavigationBar:
            _banner != null && _progress >= 1 && !_purchaseBusy && _loadError == null
            ? ColoredBox(
                color: const Color(0xFF171316),
                child: SafeArea(
                  top: false,
                  child: Center(heightFactor: 1, child: BannerSlot(ad: _banner!)),
                ),
              )
            : null,
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
