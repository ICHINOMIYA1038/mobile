/// ビルド時に差し替える設定。`--dart-define=API_BASE=http://localhost:8787` でローカルAPIに向けられる。
class AppConfig {
  AppConfig._();
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://takken-talk-api.ichiryo108.workers.dev',
  );

  /// RevenueCat の公開キー(クライアント埋め込み前提)。未設定なら課金UIは「準備中」表示になる。
  static const revenueCatPublicApiKey = String.fromEnvironment('RC_KEY', defaultValue: '');

  static const proProductId = 'jp.pairof.takken.talk.pro.monthly';
  static const pack100ProductId = 'jp.pairof.takken.talk.pack100';
  static const pack300ProductId = 'jp.pairof.takken.talk.pack300';

  static const privacyPolicyUrl = 'https://nullstead.com/apps/takken-talk/privacy';
  static const termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const supportUrl = 'https://nullstead.com/apps/takken-talk';
}
