/// ビルド時に差し替える設定。`--dart-define=API_BASE=http://localhost:5173` で手元のサイトに向けられる。
class AppConfig {
  AppConfig._();

  /// 裏側はサイト（shikaku.pairof.jp）と同じ。教材・会話・記録はすべてここから取る（docs/app-plan.md はサイトのリポジトリ）
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://shikaku.pairof.jp');
  static const exam = 'fp1';

  /// RevenueCat の公開キー(クライアント埋め込み前提。秘密鍵ではない)。未設定なら課金UIは「準備中」表示になる。
  /// RevenueCat のプロジェクト「話して受かる宅建」のアプリ「pAIrOf FP1級 (App Store)」の鍵（宅建アプリとは別。2026-10-23）。
  /// 商品は offering「fp1」・entitlement「fp1_pro」。Webhook はプロジェクトで1つ（サイトが商品 ID で FP1 の Pro と見分ける）
  static const revenueCatPublicApiKey = String.fromEnvironment('RC_KEY', defaultValue: 'appl_RlzXjFFyqSYXfKoAjoaKWYlfgvW');

  /// Pro 月額の商品 ID（App Store Connect のサブスクリプション。¥3,000/月、日本だけ）。サイトは exam.json の app.proProductPrefix
  /// （jp.pairof.fp1.talk.pro）で FP1 の Pro と見分ける
  static const proProductId = 'jp.pairof.fp1.talk.pro.monthly';

  /// Pro の学習ツール（苦手分析と学習プラン・模擬試験）を出すか。サイトの /api/v1/fp1/pro/… が FP1 の本試験形式
  /// （基礎編 四答択一50問・応用編 設例5つ、各150分、予測点は200点満点で120点が目安）を返すので出す
  static const proTools = true;

  static const privacyPolicyUrl = 'https://shikaku.pairof.jp/privacy';
  static const termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  /// サポートのページ（仮。App Store Connect のサポート URL と同じものを用意する）
  static const supportUrl = 'https://nullstead.com/apps/fp1-talk';
}
