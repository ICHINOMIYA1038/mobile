/// ビルド時に差し替える設定。`--dart-define=API_BASE=http://localhost:5173` で手元のサイトに向けられる。
class AppConfig {
  AppConfig._();

  /// 裏側はサイト（shikaku.pairof.jp）と同じ。教材・会話・記録はすべてここから取る（docs/app-plan.md はサイトのリポジトリ）
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://shikaku.pairof.jp');
  static const exam = 'takken';

  /// RevenueCat の公開キー(クライアント埋め込み前提)。未設定なら課金UIは「準備中」表示になる。
  static const revenueCatPublicApiKey = String.fromEnvironment(
    'RC_KEY',
    // RevenueCat の公開キー(クライアント埋め込み前提。秘密鍵ではない)
    defaultValue: 'appl_mskTHQrDpPGrEWGhTLqIgGemdoD',
  );

  static const proProductId = 'jp.pairof.takken.talk.pro.monthly';

  static const privacyPolicyUrl = 'https://shikaku.pairof.jp/privacy';
  static const termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const supportUrl = 'https://nullstead.com/apps/takken-talk';
}
