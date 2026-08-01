import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の設定と読み込み。
///
/// **このアプリで広告を出してよいのは結果画面（ResultScreen）だけ**。
/// カテゴリ選択画面・名前入力画面には出さない。既存の同ジャンルアプリで
/// 「ほぼ一問やるごとに広告」「診断結果を見る前に毎回広告」といった低評価が
/// 集中していたため、コア体験（入力〜診断結果を初めて見るまで）を広告で
/// 一切遮らない、という方針をこのアプリでは徹底する。
class AdService {
  /// AdMob のテスト専用ユニットID。
  /// **本番リリース前に、必ず AdMob で発行した実IDへ差し替えること。**
  /// テストIDのまま公開すると収益が発生せず、実IDでテストするとポリシー違反になる。
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  /// 本番のバナーID。空文字の間はテストIDが使われる。
  static const _prodBannerIos = 'ca-app-pub-8691137965825158/8852544345';
  static const _prodBannerAndroid = 'ca-app-pub-8691137965825158/7790478182';

  static Future<void>? _initialization;

  @visibleForTesting
  static bool disableForTests = false;

  static String get bannerUnitId {
    if (Platform.isIOS) {
      return _prodBannerIos.isEmpty ? _testBannerIos : _prodBannerIos;
    }
    return _prodBannerAndroid.isEmpty ? _testBannerAndroid : _prodBannerAndroid;
  }

  static bool get isUsingTestAds =>
      Platform.isIOS ? _prodBannerIos.isEmpty : _prodBannerAndroid.isEmpty;

  static Future<void> ensureInitialized() {
    if (disableForTests) return _initialization ??= Future.value();
    return _initialization ??= _requestConsentThenInitialize();
  }

  static Future<void> _requestConsentThenInitialize() async {
    await _requestConsent();
    await MobileAds.instance.initialize();
  }

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
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  static Future<void> _loadAndShowConsentForm() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((_) => completer.complete());
    return completer.future;
  }

  static Future<bool> canRequestAds() {
    if (disableForTests) return Future.value(false);
    return ConsentInformation.instance.canRequestAds();
  }

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

  Future<BannerAd?> loadBanner({required int width}) async {
    if (kIsWeb) return null;
    if (!Platform.isIOS && !Platform.isAndroid) return null;

    await ensureInitialized();
    if (!(await canRequestAds())) return null;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      Orientation.portrait, width,
    );
    if (size == null) return null;

    final completer = Completer<BannerAd?>();
    final banner = BannerAd(
      adUnitId: bannerUnitId,
      size: size,
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
}
