import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

  static bool _initialized = false;

  /// 実IDが未設定ならテストIDを返す。差し替え忘れても事故らないようにするため。
  static String get bannerUnitId {
    if (Platform.isIOS) {
      return _prodBannerIos.isEmpty ? _testBannerIos : _prodBannerIos;
    }
    return _prodBannerAndroid.isEmpty
        ? _testBannerAndroid
        : _prodBannerAndroid;
  }

  /// 実IDが入っているか。false ならテスト広告が表示される。
  static bool get isUsingTestAds =>
      Platform.isIOS ? _prodBannerIos.isEmpty : _prodBannerAndroid.isEmpty;

  /// SDK の初期化。
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
  }

  /// バナー広告を読み込む。失敗しても null を返すだけで、画面は通常どおり出る。
  Future<BannerAd?> loadBanner({required int width}) async {
    if (kIsWeb) return null;
    if (!Platform.isIOS && !Platform.isAndroid) return null;

    await ensureInitialized();

    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
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
