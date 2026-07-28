import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の設定と読み込み。
///
/// **このアプリで広告を出してよいのは実演画面と振り返り画面だけ**。
/// お題の生成中・役を引いている最中（他人に見せてはいけない内容が映る）には出さない。
class AdService {
  /// AdMob のテスト専用ユニットID。
  /// **本番リリース前に、必ず AdMob で発行した実IDへ差し替えること。**
  /// テストIDのまま公開すると収益が発生せず、実IDでテストするとポリシー違反になる。
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  /// 本番のバナーID。空文字の間はテストIDが使われる。
  /// AdMobで「エチュードメーカー」アプリ・広告ユニット（実演・振り返り画面バナー）を発行済み。
  static const _prodBannerIos = 'ca-app-pub-8691137965825158/2006323561';
  static const _prodBannerAndroid = 'ca-app-pub-8691137965825158/2956709081';

  static Future<void>? _initialization;

  /// widgetテスト実行時にtrueにすると、AdMob/UMPの実チャンネル呼び出しを一切行わない。
  /// google_mobile_adsのシングルトンは初回アクセス時に未捕捉のプラットフォームチャンネル
  /// 呼び出しを発火する作りのため、実チャンネルのない単体テスト環境では
  /// MissingPluginExceptionが呼び出し側で捕まえられない形で発生してしまう。
  /// `test/flutter_test_config.dart` で全テスト共通にtrueへ設定している。
  @visibleForTesting
  static bool disableForTests = false;

  /// 実IDが未設定ならテストIDを返す。差し替え忘れても事故らないようにするため。
  static String get bannerUnitId {
    if (Platform.isIOS) {
      return _prodBannerIos.isEmpty ? _testBannerIos : _prodBannerIos;
    }
    return _prodBannerAndroid.isEmpty ? _testBannerAndroid : _prodBannerAndroid;
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
  /// 対象地域外や取得済みの場合は何も表示せずすぐ完了する。
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
    // 通信環境などでコールバックが返らない場合に備え、無限に待たない。
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {});
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

  /// 同意の見直し用フォームを表示する。
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
      // 常に非パーソナライズ広告にする。
      // これにより iOS のトラッキング許可ダイアログ（ATT）を出す必要がなくなり、
      // 端末の広告IDを追跡目的で使わずに済む。
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) => completer.complete(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // 広告が出ないこと自体は障害ではない。エチュードの練習は続けられる。
          completer.complete(null);
        },
      ),
    );

    await banner.load();
    return completer.future;
  }
}
