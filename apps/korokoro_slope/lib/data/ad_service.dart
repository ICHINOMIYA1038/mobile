import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の同意取得(UMP)と読み込み・表示。
///
/// リトライ時のインタースティシャルと、コンティニュー/スキン解放用のリワードのみを
/// 使用する（ハイパーカジュアルではバナーは離脱要因になりやすいため採用しない）。
/// 広告が出せない・読み込めない場合でも例外は投げず、ゲーム進行を止めない設計にする
/// (`apps/etude_generator/lib/data/ad_service.dart` の方針を踏襲)。
class AdService {
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

  /// 本番の広告ユニットID。空文字の間はテストIDが使われる。
  /// テストIDのまま公開すると収益が発生せず、実IDのままテストするとポリシー違反になる。
  /// iOSはAdMobアプリ登録・広告ユニット発行済み(2026-08-04)。Androidは未登録のため引き続き空文字。
  static const _prodInterstitialIos = 'ca-app-pub-8691137965825158/3295135332';
  static const _prodInterstitialAndroid = '';
  static const _prodRewardedIos = 'ca-app-pub-8691137965825158/5342448245';
  static const _prodRewardedAndroid = '';

  /// 端末側のAdMob SDK/OS側の不具合で全画面広告の閉じたイベントが飛んでこない
  /// (実機/エミュレータで確認できた既知の事象。Play開発者サービスが古い環境など)
  /// 場合でも、Futureが永久に解決されないまま残らないようにする保険のタイムアウト。
  static const _dismissFallbackTimeout = Duration(seconds: 90);

  static Future<void>? _initialization;

  /// ATT許諾(iOS)とGDPR同意(UMP)の両方が得られた場合のみパーソナライズ広告を要求する。
  /// どちらか一方でも未許諾/対象外なら、安全側に倒して非パーソナライズ広告のままにする。
  static bool _personalizedAdsAllowed = false;

  /// widgetテスト実行時にtrueにすると、AdMob/UMPの実チャンネル呼び出しを一切行わない。
  /// `test/flutter_test_config.dart` で全テスト共通にtrueへ設定する。
  @visibleForTesting
  static bool disableForTests = false;

  static String get _interstitialUnitId {
    if (Platform.isIOS) {
      return _prodInterstitialIos.isEmpty ? _testInterstitialIos : _prodInterstitialIos;
    }
    return _prodInterstitialAndroid.isEmpty ? _testInterstitialAndroid : _prodInterstitialAndroid;
  }

  static String get _rewardedUnitId {
    if (Platform.isIOS) {
      return _prodRewardedIos.isEmpty ? _testRewardedIos : _prodRewardedIos;
    }
    return _prodRewardedAndroid.isEmpty ? _testRewardedAndroid : _prodRewardedAndroid;
  }

  /// EEA/UK等での同意取得（UMP）とSDK初期化。同時に複数回呼ばれても1回だけ実行される。
  static Future<void> ensureInitialized() {
    if (disableForTests) return _initialization ??= Future.value();
    return _initialization ??= _requestConsentThenInitialize();
  }

  static Future<void> _requestConsentThenInitialize() async {
    await _requestConsent();
    // Androidは対象外(元からnonPersonalizedAds: true固定、挙動は変えない)。
    // iOSのみATTの許諾結果でパーソナライズ広告の可否を決める。
    _personalizedAdsAllowed = Platform.isIOS && await _requestAttOnIOS();
    await MobileAds.instance.initialize();
  }

  /// iOSのApp Tracking Transparency許諾ダイアログを表示し、結果を待つ。
  /// Googleの推奨どおり、この完了コールバックが返るまで広告読み込みを待つ
  /// (先に広告を読み込むと、許諾が得られてもIDFAが広告リクエストに反映されないため)。
  static Future<bool> _requestAttOnIOS() async {
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status == TrackingStatus.authorized;
    } catch (_) {
      // ATT呼び出し自体に失敗しても広告表示は止めず、非パーソナライズ側に倒す。
      return false;
    }
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

  /// 同意が必要な地域で未取得のままなら、広告を出さない。
  static Future<bool> canRequestAds() {
    if (disableForTests) return Future.value(false);
    return ConsentInformation.instance.canRequestAds();
  }

  static Future<bool> isPrivacyOptionsRequired() async {
    if (disableForTests) return false;
    final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  static Future<void> showPrivacyOptionsForm() {
    if (disableForTests) return Future.value();
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => completer.complete());
    return completer.future;
  }

  /// インタースティシャル広告を読み込んで表示する。表示できたか(shown)を返す。
  /// 読み込み・表示に失敗しても例外は投げず false を返すだけ。
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
    return completer.future.timeout(_dismissFallbackTimeout, onTimeout: () => true);
  }

  Future<InterstitialAd?> _loadInterstitial() {
    final completer = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: AdRequest(nonPersonalizedAds: !_personalizedAdsAllowed),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => completer.complete(ad),
        onAdFailedToLoad: (error) => completer.complete(null),
      ),
    );
    return completer.future;
  }

  /// リワード広告を読み込んで表示する。視聴完了して報酬を得られたら true。
  /// 読み込み失敗・視聴中断のいずれでも例外は投げず false を返す。
  Future<bool> showRewarded() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return false;
    await ensureInitialized();
    if (!(await canRequestAds())) return false;

    final ad = await _loadRewarded();
    if (ad == null) return false;

    var earnedReward = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {},
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(
      onUserEarnedReward: (ad, reward) => earnedReward = true,
    );
    // onAdDismissedFullScreenContentが端末側の事情で発火しない場合でも、視聴完了して
    // 既に報酬済みなら true としてゲームを進められるようにする(閉じ忘れによる無限待ち防止)。
    return completer.future.timeout(_dismissFallbackTimeout, onTimeout: () => earnedReward);
  }

  Future<RewardedAd?> _loadRewarded() {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: AdRequest(nonPersonalizedAds: !_personalizedAdsAllowed),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => completer.complete(ad),
        onAdFailedToLoad: (error) => completer.complete(null),
      ),
    );
    return completer.future;
  }
}
