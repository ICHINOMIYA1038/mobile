import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import '../state/app_state.dart';

/// 広告を出してよい人か。Pro の人には出さない。自分（/api/v1/me）を読めていないあいだも出さない（Pro の人に一瞬出ないように）。
/// AppScope.of(context) で読んだ state を渡せば、Pro になった瞬間に描き直されて消える。
bool adsAllowed(AppState state) => adsAllowedFor(state.me);
bool adsAllowedFor(Map<String, dynamic>? me) => me != null && me['pro'] != true;

/// 全画面広告（過去問の「次の問題」で出すもの）の間隔の決まり。時計を差し替えて試せるように画面や SDK から切り離す。
///   - 過去問を [every] 問答えるごと（回をまたいで数える。アプリを閉じれば 0 に戻る）
///   - 前に出してから [gap] 以上あける
///   - 起動してから [grace] のあいだは出さない
/// 条件がそろわないときは数え続け、そろった次の「次の問題」で出す。
class InterstitialPolicy {
  InterstitialPolicy({DateTime Function()? clock, DateTime? launchedAt, this.every = 10, this.gap = const Duration(minutes: 3), this.grace = const Duration(minutes: 3)})
      : _clock = clock ?? DateTime.now,
        launchedAt = launchedAt ?? (clock ?? DateTime.now)();

  final DateTime Function() _clock;
  DateTime launchedAt;
  final int every;
  final Duration gap;
  final Duration grace;

  /// 前に出してから答えた問題の数
  int answered = 0;
  DateTime? lastShown;

  void onAnswered() => answered++;

  bool get due {
    final now = _clock();
    if (answered < every) return false;
    if (now.difference(launchedAt) < grace) return false;
    final last = lastShown;
    return last == null || now.difference(last) >= gap;
  }

  void onShown() {
    lastShown = _clock();
    answered = 0;
  }
}

/// 広告（AdMob）。Pro でない人にだけ、一覧の画面の下のバナーと、過去問を10問解くごとの全画面広告を出す。
///
/// **会話（learn_screen）・AIに聞く（explain_sheet）・Pro の画面・設定・模擬試験には出さない。**
/// 学ぶ流れの途中を広告で切らないため。test/ads_test.dart がそれを確かめている。
///
/// 広告は常に非パーソナライズ（AdRequest(nonPersonalizedAds: true)）。端末の広告 ID を追跡に使わないので、
/// トラッキングの許可（ATT）も EU の同意（UMP）も出さない。パーソナライズ広告に変えるなら両方が要る。
/// SDK は Pro でない人に最初の広告を出すときまで起動しない。
class AdService {
  AdService._();
  static final instance = AdService._();

  // 本番の広告ユニット（AdMob のアプリ「pAIrOf FP1級」iOS）。アプリ ID は Info.plist の GADApplicationIdentifier。
  // 2026-10-23 に AdMob に登録（アプリ ID ca-app-pub-8691137965825158~6412568866）。
  // 宅建アプリの ID は使わない（収益と広告の設定がアプリごとのため）。
  // 開発中（debug ビルド。手元の実行や integration_test）は Google のテスト用 ID を使う。
  // 本番の ID で自分が広告を見たり押したりするとポリシー違反になるため。リリースのビルドだけが本番の ID を使う。
  // test/release_readiness_test.dart が、本番の ID が入ったら Google のテスト用でないことを、提出前の確認では空でないことを確かめる。
  static const _prodBannerIos = 'ca-app-pub-8691137965825158/2369382075';
  static const _prodInterstitialIos = 'ca-app-pub-8691137965825158/6368336830';

  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  /// 本番の広告ユニットがまだ入っていない（AdMob に未登録）
  static bool get prodIdsMissing => _prodBannerIos.isEmpty || _prodInterstitialIos.isEmpty;

  /// debug ビルドはテスト用 ID（本番の ID では試さない）。本番の ID が無いあいだはリリースでもテスト用
  static bool get isUsingTestAds => kDebugMode || prodIdsMissing;

  static String bannerUnitIdFor({required bool test}) => test || _prodBannerIos.isEmpty ? _testBannerIos : _prodBannerIos;
  static String interstitialUnitIdFor({required bool test}) => test || _prodInterstitialIos.isEmpty ? _testInterstitialIos : _prodInterstitialIos;
  static String get bannerUnitId => bannerUnitIdFor(test: isUsingTestAds);
  static String get interstitialUnitId => interstitialUnitIdFor(test: isUsingTestAds);

  /// iOS だけ（Android の ID はまだ無い）
  static bool get supported => !kIsWeb && Platform.isIOS;

  static const _request = AdRequest(nonPersonalizedAds: true);

  final policy = InterstitialPolicy();
  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  /// 起動した時刻を覚える（起動してすぐは全画面広告を出さない）。main() で呼ぶ。SDK は起動しない
  void markLaunched() => policy.launchedAt = DateTime.now();

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (_) {
      // 初期化の失敗は広告が出ないだけ。次の読み込みでやり直す（投げると Crashlytics にクラッシュとして残る）
    }
    return _initialized;
  }

  /// 画面の下のバナー（アンカー型のアダプティブ）。読めなければ null（画面はそのまま）
  Future<BannerAd?> loadBanner({required int width, Orientation orientation = Orientation.portrait}) async {
    if (!supported || !await _ensureInitialized()) return null;
    try {
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(orientation, width);
      if (size == null) return null;
      final done = Completer<BannerAd?>();
      final banner = BannerAd(
        adUnitId: bannerUnitId,
        size: size,
        request: _request,
        listener: BannerAdListener(
          onAdLoaded: (ad) => done.complete(ad as BannerAd),
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            done.complete(null);
          },
        ),
      );
      await banner.load();
      return done.future;
    } catch (_) {
      return null;
    }
  }

  /// 全画面広告を先に読んでおく（過去問を開いたとき）。もう読んであれば何もしない
  Future<void> preloadInterstitial() async {
    if (_interstitial != null || _loadingInterstitial || !supported) return;
    _loadingInterstitial = true;
    try {
      if (!await _ensureInitialized()) return;
      await InterstitialAd.load(
        adUnitId: interstitialUnitId,
        request: _request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (_) => _loadingInterstitial = false,
        ),
      );
    } catch (_) {
      _loadingInterstitial = false;
    }
  }

  /// 過去問を1問答えた（採点が返ってきた）
  void onKakomonAnswered() => policy.onAnswered();

  /// 過去問の「次の問題」を押したときに呼ぶ。間隔の決まりを満たし、読んであれば全画面広告を出す。
  /// 出せなくても何も言わない（学習はそのまま続く）。出したかどうかを返す
  bool maybeShowInterstitial() {
    final ad = _interstitial;
    if (!policy.due) return false;
    if (ad == null) {
      preloadInterstitial();
      return false;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadInterstitial();
      },
    );
    policy.onShown();
    unawaited(ad.show().catchError((Object _) => ad.dispose()));
    return true;
  }
}
