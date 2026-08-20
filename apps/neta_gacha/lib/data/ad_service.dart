import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の設定・同意取得(UMP)・読み込み・表示。
///
/// バナーはRouletteScreenの常設フッターにのみ表示し、インタースティシャルは
/// RouletteScreenで一定回数抽選するごとに挟む。それ以外の画面(Home/Favorites/
/// CustomPrompt/Settings)には出さない。
class AdService {
  /// AdMob のテスト専用ユニットID。
  /// **本番リリース前に、必ず AdMob で発行した実IDへ差し替えること。**
  /// テストIDのまま公開すると収益が発生せず、実IDでテストするとポリシー違反になる。
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';

  /// 本番の広告ユニットID。空文字の間はテストIDが使われる。
  /// AdMobで「ネタガチャ」(iOS)を登録し、実アプリID・実広告ユニットIDに差し替え済み
  /// (2026-08-19)。Androidは未対応のためテストIDのまま。
  static const _prodBannerIos = 'ca-app-pub-8691137965825158/2874151289';
  static const _prodBannerAndroid = '';
  static const _prodInterstitialIos =
      'ca-app-pub-8691137965825158/7317577145';
  static const _prodInterstitialAndroid = '';

  /// 端末側のAdMob SDK/OS側の不具合で全画面広告の閉じたイベントが飛んでこない場合でも、
  /// Futureが永久に解決されないまま残らないようにする保険のタイムアウト。
  static const _dismissFallbackTimeout = Duration(seconds: 90);

  static Future<void>? _initialization;

  /// widgetテスト実行時にtrueにすると、AdMob/UMPの実チャンネル呼び出しを一切行わない。
  /// `test/flutter_test_config.dart` で全テスト共通にtrueへ設定する。
  @visibleForTesting
  static bool disableForTests = false;

  static String get bannerUnitId {
    if (Platform.isIOS) {
      return _prodBannerIos.isEmpty ? _testBannerIos : _prodBannerIos;
    }
    return _prodBannerAndroid.isEmpty
        ? _testBannerAndroid
        : _prodBannerAndroid;
  }

  static String get _interstitialUnitId {
    if (Platform.isIOS) {
      return _prodInterstitialIos.isEmpty
          ? _testInterstitialIos
          : _prodInterstitialIos;
    }
    return _prodInterstitialAndroid.isEmpty
        ? _testInterstitialAndroid
        : _prodInterstitialAndroid;
  }

  /// 実IDが入っているか。false ならテスト広告が表示される。
  static bool get isUsingTestAds =>
      Platform.isIOS ? _prodBannerIos.isEmpty : _prodBannerAndroid.isEmpty;

  /// EEA/UK等での同意取得（UMP）とSDK初期化。同時に複数回呼ばれても1回だけ実行される。
  static Future<void> ensureInitialized() {
    if (disableForTests) return _initialization ??= Future.value();
    return _initialization ??= _requestConsentThenInitialize();
  }

  static Future<void> _requestConsentThenInitialize() async {
    await _requestConsent();
    await MobileAds.instance.initialize();
  }

  /// GoogleのEU User Consent Policyに基づき、必要な地域でのみ同意フォームを表示する。
  static Future<void> _requestConsent() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          await _loadAndShowConsentForm();
        }
        if (!completer.isCompleted) completer.complete();
      },
      (_) {
        // 同意情報の取得に失敗しても、広告なしでアプリの利用は続けられるようにする。
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  static Future<void> _loadAndShowConsentForm() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((_) => completer.complete());
    return completer.future;
  }

  /// 同意が必要な地域で未取得のままなら、広告を出さない。
  static Future<bool> canRequestAds() {
    if (disableForTests) return Future.value(false);
    return ConsentInformation.instance.canRequestAds();
  }

  /// 設定画面などから同意内容をいつでも見直せるようにする入り口が必要か。
  static Future<bool> isPrivacyOptionsRequired() async {
    if (disableForTests) return false;
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  static Future<void> showPrivacyOptionsForm() {
    if (disableForTests) return Future.value();
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => completer.complete());
    return completer.future;
  }

  /// バナー広告を読み込む。失敗しても null を返すだけで、画面は通常どおり出る。
  Future<BannerAd?> loadBanner({required int width}) async {
    if (kIsWeb) return null;
    if (!Platform.isIOS && !Platform.isAndroid) return null;

    await ensureInitialized();
    if (!(await canRequestAds())) return null;

    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          Orientation.portrait,
          width,
        );
    if (size == null) return null;

    final completer = Completer<BannerAd?>();
    final banner = BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      // 常に非パーソナライズ広告にする(iOSのATTダイアログを避け、広告IDを追跡目的で使わない)。
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) => completer.complete(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          completer.complete(null);
        },
      ),
    );

    await banner.load();
    return completer.future;
  }

  /// インタースティシャル広告を読み込んで表示する。表示できたか(shown)を返す。
  /// 読み込み・表示に失敗しても例外は投げず false を返すだけ(抽選は止めない)。
  Future<bool> showInterstitial() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return false;
    await ensureInitialized();
    if (!(await canRequestAds())) return false;

    final ad = await _loadInterstitial();
    if (ad == null) return false;

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {},
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show();
    return completer.future.timeout(
      _dismissFallbackTimeout,
      onTimeout: () => true,
    );
  }

  Future<InterstitialAd?> _loadInterstitial() {
    final completer = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => completer.complete(ad),
        onAdFailedToLoad: (error) => completer.complete(null),
      ),
    );
    return completer.future;
  }
}
