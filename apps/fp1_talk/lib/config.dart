/// ビルド時に差し替える設定。`--dart-define=API_BASE=http://localhost:5173` で手元のサイトに向けられる。
class AppConfig {
  AppConfig._();

  /// 裏側はサイト（shikaku.pairof.jp）と同じ。教材・会話・記録はすべてここから取る（docs/app-plan.md はサイトのリポジトリ）
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://shikaku.pairof.jp');
  static const exam = 'fp1';

  /// RevenueCat の公開キー(クライアント埋め込み前提。秘密鍵ではない)。未設定なら課金UIは「準備中」表示になる。
  /// **FP1 アプリはまだ RevenueCat に登録していないので空**。RevenueCat にこのアプリ（jp.pairof.fp1.talk）を足したら、
  /// その「appl_…」の公開キーを defaultValue に入れる（宅建アプリのキーは使わない。Pro が別の商品のため）。
  static const revenueCatPublicApiKey = String.fromEnvironment('RC_KEY', defaultValue: '');

  /// Pro 月額の商品 ID（仮。App Store Connect で作った ID に合わせる）。サイトは exam.json の app.proProductPrefix
  /// （jp.pairof.fp1.talk.pro）で FP1 の Pro と見分ける
  static const proProductId = 'jp.pairof.fp1.talk.pro.monthly';

  /// Pro の学習ツール（苦手分析と学習プラン・模擬試験）を出すか。サイトの苦手分析と模擬試験はまだ○×の過去問（宅建）の形で、
  /// FP1 の本試験形式（基礎編50問＋応用編）に合わせていない（サイトの docs/handoff.md の「まだ」）。合わせたら true にする
  static const proTools = false;

  static const privacyPolicyUrl = 'https://shikaku.pairof.jp/privacy';
  static const termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  /// サポートのページ（仮。App Store Connect のサポート URL と同じものを用意する）
  static const supportUrl = 'https://nullstead.com/apps/fp1-talk';
}
