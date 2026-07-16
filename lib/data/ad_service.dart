import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
// Orientation を使うため widgets も取る。
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の設定と読み込み。
///
/// **このアプリで広告を出してよいのは結果画面だけ**。
/// 競合の最大の不満が「広告が邪魔で集中できない」であり、
/// 出題中・解説中に広告を出した時点でこのアプリの存在理由が消える。
/// バナーを増やしたくなったら、まずその前提を疑うこと。
class AdService {
  AdService({this.isEnabled = true});

  /// 広告削除を購入済みなら false。以後 AdService は一切の広告を読み込まない。
  final bool isEnabled;

  /// AdMob のテスト専用ユニットID。
  /// **本番リリース前に、必ず AdMob で発行した実IDへ差し替えること。**
  /// テストIDのまま公開すると収益が発生せず、実IDでテストするとポリシー違反になる。
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  /// 本番のバナーID。空文字の間はテストIDが使われる。
  static const _prodBannerIos = '';
  static const _prodBannerAndroid = '';

  static bool _initialized = false;

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

  /// SDK の初期化。広告を出さない場合は呼ばない（＝SDKを起動しない）。
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
  }

  /// 結果画面用のバナーを読み込む。失敗しても null を返すだけで、画面は通常どおり出る。
  Future<BannerAd?> loadResultBanner({required int width}) async {
    if (!isEnabled) return null;
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
      // 端末の広告IDを追跡目的で使わずに済む。データを外に出さないという方針と揃える。
      // 収益を優先してパーソナライズ広告に変えるなら、ATTとEUの同意取得(UMP)が別途必要。
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) => completer.complete(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // 広告が出ないこと自体は障害ではない。学習は続けられる。
          completer.complete(null);
        },
      ),
    );

    await banner.load();
    return completer.future;
  }
}
