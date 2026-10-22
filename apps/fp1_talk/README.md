# fp1_talk

iOS アプリ「AIとチャットしながら学ぶFP1級 - pAIrOf」（ホーム画面は「pAIrOf FP1級」、Bundle ID `jp.pairof.fp1.talk`）。
宅建アプリ（apps/takken_talk）を写して FP1 用に直したもの。共通パッケージへの切り出しは宅建アプリの公開後。

- 裏側はサイト（~/private/pairof-shikaku、shikaku.pairof.jp）の `/api/v1/fp1/…`。仕様はサイトの docs/app-api.md
- 画面: 学ぶ（章の講義と AI の先生との会話・○×）/ 本試験形式（回×編・章 → 1問ずつ。四答択一・空欄・計算・設例・電卓）/ 復習 / 図解 / 設定・Pro
- 本試験形式の問は、答え合わせのあと「AIに聞く」（サイトの /api/v1/fp1/item-explain。正解・解説はサーバーが入れる。回数は ○× の「AIに聞く」と同じ）
- Pro の学習ツール（`AppConfig.proTools = true`）: 苦手分析（予測点 200点満点・合格の目安 120点、基礎編・応用編ごと。応用編の配点は推定と表示）と、模擬試験（基礎編 四答択一50問・応用編 設例5つ、各150分。解く画面は本試験形式と同じで電卓つき、結果から問ごとに答え・正解・解説・AIに聞く）
- 復習の「まちがえた」の上に、本試験形式（過去問・模擬試験）で前回まちがえた問。押すとその問から、「まとめて解き直す」で全部（サイトの items/wrong）
- 自分（/api/v1/me）は `?exam=fp1` を付けて読む（Pro は試験ごと）

## 確かめ方
- `flutter analyze`、`flutter test`（`dart format` は流さない）
- 通し: サイトの worktree で `pnpm dev --port 3150`（AI はモック）→
  `tool/shots.sh <シミュレーターの UDID> tool/shots integration_test/fp1_flow_test.dart --dart-define=API_BASE=http://localhost:3150`
  （「SHOT 名前」のところで tool/shots/ に画面を撮る）。会話の入力欄は integration_test/keyboard_test.dart
- Pro（模擬試験・苦手分析・本試験形式の「AIに聞く」・復習）: integration_test/fp1_pro_test.dart。Pro の学習者を手元の D1 に作ってトークンを渡す（手順はファイルの頭）

## 出す前にオーナーが登録して、値を入れる所
| 登録 | 入れる所 |
|---|---|
| App Store Connect のアプリ（jp.pairof.fp1.talk）と Pro 月額（仮 ID `jp.pairof.fp1.talk.pro.monthly`） | ID を変えたら lib/config.dart の `proProductId` と ios/Runner/Products.storekit |
| RevenueCat にこのアプリ・商品・Webhook（`https://shikaku.pairof.jp/api/v1/webhooks/revenuecat`） | 公開キー `appl_…` を lib/config.dart の `revenueCatPublicApiKey`（空のあいだ購入は「準備中」） |
| AdMob のアプリ「pAIrOf FP1級」とバナー・インタースティシャル | lib/ads/ad_service.dart の `_prodBannerIos`・`_prodInterstitialIos`、ios/Runner/Info.plist の `GADApplicationIdentifier`（いまは Google のテスト用。test/release_readiness_test.dart の提出前の確認は空のあいだ skip） |
| Firebase（iOS アプリ jp.pairof.fp1.talk） | このフォルダで `flutterfire configure`（lib/firebase_options.dart と GoogleService-Info.plist、Crashlytics の手順が足される。いまは null で計測なし） |
| サポートのページ | lib/config.dart の `supportUrl`（仮） |
| アイコン | icon/icon.png（仮）→ `dart run flutter_launcher_icons` |

## TestFlight（2026-10-23 から）
- App Store Connect のアプリ id `6825911478`。内部テストのグループ「開発」（全ビルドを配る）。Bundle ID と配布用プロファイル「pAIrOf FP1 App Store」は ASC API で作った（証明書は宅建と同じ Apple Distribution）
- ビルドの出し方: `flutter build ios --release --config-only` → `xcodebuild … archive -allowProvisioningUpdates`（API キー）→ `xcodebuild -exportArchive`（build/ios/ipa/ExportOptions.plist は手動署名・上のプロファイル）→ `xcrun altool --upload-app`。手順の細部は ~/private/mobile の docs/maintenance.md 8.
- つなぎ先は本番（shikaku.pairof.jp）。FP1 は exam.json の draft のあいだ Web には出ず、API からだけ引ける（サイトの fp1-integration ブランチ）
