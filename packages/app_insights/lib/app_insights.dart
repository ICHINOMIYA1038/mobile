import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 全アプリ共通の計測窓口。
///
/// 各アプリは `main()` で [initialize] を一度呼び、あとは [logEvent] と
/// [navigatorObservers] だけを使う。アプリ側が Firebase のクラスを直接
/// 触らないので、計測基盤を差し替えたくなったときにここだけ直せば済む。
///
/// 計測はアプリを落としてまで守るものではない、という方針で作ってある。
/// 初期化に失敗した場合（設定ファイル未生成、未対応プラットフォーム、
/// ユニットテスト中など）は [isEnabled] が false になり、以降の呼び出しは
/// すべて黙って何もしない。
class AppInsights {
  AppInsights._();

  static FirebaseAnalytics? _analytics;
  static List<NavigatorObserver> _navigatorObservers = const [];

  /// 計測が有効か。初期化に失敗していれば false。
  static bool get isEnabled => _analytics != null;

  /// `MaterialApp.navigatorObservers` にそのまま渡す。
  ///
  /// 画面遷移が `screen_view` として自動記録される。ただし記録されるのは
  /// `RouteSettings.name` が設定されているルートだけなので、
  /// `MaterialPageRoute(settings: RouteSettings(name: 'xxx'), ...)` のように
  /// 名前を付けること。付け忘れた画面は GA4 上で存在しないことになる。
  static List<NavigatorObserver> get navigatorObservers => _navigatorObservers;

  /// Firebase Analytics と Crashlytics を初期化する。
  ///
  /// [options] には `flutterfire configure` が生成した
  /// `DefaultFirebaseOptions.currentPlatform` を渡す。
  ///
  /// [collectInDebug] を false のままにしておくと、デバッグビルドの
  /// セッションが本番の DAU や継続率に混ざらない。計測の実装を実機で
  /// 確認したいときだけ true にする。
  static Future<void> initialize({
    required FirebaseOptions options,
    bool collectInDebug = false,
  }) async {
    try {
      await Firebase.initializeApp(options: options);
    } catch (error, stackTrace) {
      // 設定ファイル未生成、オフライン、flutterfire configure の対象外
      // プラットフォーム（web / macOS）などで到達する。
      debugPrint('AppInsights: 初期化に失敗したため計測を無効化します: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    final collect = collectInDebug || !kDebugMode;

    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(collect);
    _analytics = analytics;
    _navigatorObservers = [FirebaseAnalyticsObserver(analytics: analytics)];

    // Crashlytics は web 未対応。
    if (kIsWeb) return;

    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(collect);

    // Flutter フレームワーク内で投げられた例外。
    // presentError を残しているのは、デバッグ時にコンソールへ出す既定の
    // 挙動を潰さないため。
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterError(details);
    };

    // フレームワークの外（非同期処理など）まで抜けてしまった例外。
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// カスタムイベントを記録する。
  ///
  /// [name] と [parameters] のキーは GA4 の制約（英数字とアンダースコア、
  /// 英字始まり、40文字以内、`firebase_` `google_` `ga_` 始まりは予約）に
  /// 従う必要がある。違反したイベントはエラーにならず GA4 側で黙って
  /// 捨てられるため、デバッグビルドでは assert で気付けるようにしてある。
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    assert(_isValidName(name), '不正なイベント名です: $name');
    assert(
      parameters == null || parameters.keys.every(_isValidName),
      'イベント $name に不正なパラメータ名が含まれています',
    );
    assert(
      (parameters?.length ?? 0) <= 25,
      'イベント $name のパラメータが25個を超えています',
    );

    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      debugPrint('AppInsights: イベント $name の記録に失敗しました: $error');
    }
  }

  /// ユーザー属性を設定する。GA4 で「この属性を持つ人の継続率」のように
  /// セグメントを切るために使う。個人を特定できる値は入れないこと。
  static Future<void> setUserProperty(String name, String? value) async {
    assert(_isValidName(name), '不正なユーザー属性名です: $name');

    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.setUserProperty(name: name, value: value);
    } catch (error) {
      debugPrint('AppInsights: ユーザー属性 $name の設定に失敗しました: $error');
    }
  }

  /// 捕捉済みだが記録しておきたいエラーを Crashlytics に送る。
  /// クラッシュしていないので [fatal] は既定で false。
  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (_analytics == null || kIsWeb) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('AppInsights: エラーの記録に失敗しました: $e');
    }
  }

  /// テスト用。初期化前の状態に戻す。
  @visibleForTesting
  static void resetForTesting() {
    _analytics = null;
    _navigatorObservers = const [];
  }

  static final _namePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
  static const _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  static bool _isValidName(String name) {
    if (name.length > 40) return false;
    if (!_namePattern.hasMatch(name)) return false;
    return !_reservedPrefixes.any(name.startsWith);
  }
}
