# fp1_talk

iOS アプリ「AIとチャットしながら学ぶFP1級 - pAIrOf」（ホーム画面は「pAIrOf FP1級」、Bundle ID `jp.pairof.fp1.talk`）。
宅建アプリ（apps/takken_talk）を写して FP1 用に直したもの。共通パッケージへの切り出しは宅建アプリの公開後。

- 裏側はサイト（~/private/pairof-shikaku、shikaku.pairof.jp）の `/api/v1/fp1/…`。仕様はサイトの docs/app-api.md
- 画面: 学ぶ（章の講義と AI の先生との会話・○×）/ 本試験形式（回×編・章 → 1問ずつ。四答択一・空欄・計算・設例・電卓）/ 復習 / 図解 / 設定・Pro
- Pro の学習ツール（苦手分析・模擬試験）は `AppConfig.proTools = false` で隠している（サイトが FP1 の本試験形式にまだ合わせていない）

## 確かめ方
- `flutter analyze`、`flutter test`（`dart format` は流さない）
- 通し: サイトの worktree で `pnpm dev --port 3150`（AI はモック）→
  `tool/shots.sh <シミュレーターの UDID> tool/shots integration_test/fp1_flow_test.dart --dart-define=API_BASE=http://localhost:3150`
  （「SHOT 名前」のところで tool/shots/ に画面を撮る）。会話の入力欄は integration_test/keyboard_test.dart

## 出す前にオーナーが登録して、値を入れる所
| 登録 | 入れる所 |
|---|---|
| App Store Connect のアプリ（jp.pairof.fp1.talk）と Pro 月額（仮 ID `jp.pairof.fp1.talk.pro.monthly`） | ID を変えたら lib/config.dart の `proProductId` と ios/Runner/Products.storekit |
| RevenueCat にこのアプリ・商品・Webhook（`https://shikaku.pairof.jp/api/v1/webhooks/revenuecat`） | 公開キー `appl_…` を lib/config.dart の `revenueCatPublicApiKey`（空のあいだ購入は「準備中」） |
| AdMob のアプリ「pAIrOf FP1級」とバナー・インタースティシャル | lib/ads/ad_service.dart の `_prodBannerIos`・`_prodInterstitialIos`、ios/Runner/Info.plist の `GADApplicationIdentifier`（いまは Google のテスト用。test/release_readiness_test.dart の提出前の確認は空のあいだ skip） |
| Firebase（iOS アプリ jp.pairof.fp1.talk） | このフォルダで `flutterfire configure`（lib/firebase_options.dart と GoogleService-Info.plist、Crashlytics の手順が足される。いまは null で計測なし） |
| サポートのページ | lib/config.dart の `supportUrl`（仮） |
| アイコン | icon/icon.png（仮）→ `dart run flutter_launcher_icons` |
