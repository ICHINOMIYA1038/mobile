import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 画面の下に出すバナー広告（AdMob）。2026-11-18 オーナー決定で、無料の人にだけ出す。
///
/// 出すかどうかは Web 側が決めて知らせる（Pro の人・ログイン確認中には出さない。
/// main.dart の TomoshibiApp チャンネル）。アプリで Pro を買った人にも出さない。
class AdService {
  AdService._();

  /// AdMob のテスト専用のバナー ID。リリース版でない（手元で試す）ときはこちらを使う。
  /// 本物の ID で試しの表示を繰り返すと、AdMob のポリシー違反になる。
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  /// 本番のバナー ID（AdMob のアプリ「TOMOSHIBI小屋」の広告ユニット「画面下バナー」、2026-11-18 作成）
  static const _prodBannerIos = 'ca-app-pub-8691137965825158/6850922645';

  static String get bannerUnitId =>
      kReleaseMode ? _prodBannerIos : _testBannerIos;

  static bool _initialized = false;

  /// SDK の初期化と、EU などで要る同意の確認（UMP）。広告を出さない人には呼ばない。
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await _requestConsentIfRequired();
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (_) {
      // 初期化に失敗しても、広告が出ないだけ。次に読み込むときにやり直す。
    }
  }

  static Future<void> _requestConsentIfRequired() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  /// 320×50 のバナーを読み込む。失敗したら null（画面はそのまま使える）。
  /// 高さを 50 に決めておき、舞台を見る場所を前の「購入を復元」の帯（48）と同じくらいに保つ。
  /// [personalized] は ATT で許可されたときだけ true にする。
  static Future<BannerAd?> loadBanner({required bool personalized}) async {
    if (!Platform.isIOS) return null;
    await ensureInitialized();
    const size = AdSize.banner;
    final completer = Completer<BannerAd?>();
    final banner = BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: AdRequest(nonPersonalizedAds: !personalized),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    try {
      await banner.load();
    } catch (_) {
      banner.dispose();
      return null;
    }
    return completer.future;
  }
}

/// 読み込んだバナーを、その大きさのまま置く。
class BannerSlot extends StatelessWidget {
  const BannerSlot({super.key, required this.ad});
  final BannerAd ad;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
}
