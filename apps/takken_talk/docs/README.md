# 話して受かる宅建（takken_talk）

AIチューターと会話しながら宅建の全11章を学ぶアプリ。企画・設計は `docs/takken-ai-tutor-plan.md`（リポジトリ直下 docs）。
バックエンドは別リポジトリ `~/private/takken-talk-api`（Cloudflare Workers + D1 + Claude `claude-sonnet-5`）。

## 仕組み（ざっくり）
- 端末は初回起動で `POST /v1/users` → 匿名IDとトークンを SharedPreferences に保存。ログインなし。
- 章ごとに1本の会話。`POST /v1/chat` に「発言」か「○×カードの回答」を送ると SSE で返答が流れる。
- 出題はサーバのツール `get_next_question`（takken_simple の300問）。カードで答えるとサーバが採点・SM-2で次回出題日を決める。
- 体系は「4科目 → 11章 → 53の小テーマ」。ホームは科目で束ねて本試験の配点（業法20・権利14・制限8・税8）を出し、
  チャット上部には現在地（3/7 テーマ名）を常時出す。現在地は AI の `set_topic` だけに頼らず、出題と図解からも自動で追随する。
- 図解は `content/figures/*.json` に77枚。AI が `show_figure` で呼び、アプリがネイティブに描く（比較表・グループ分け・数字・流れ図・入れ子）。
  AI に図を生成させないのは、宅建は数字の正確さが命で、生成のたびに内容が揺れると信用を失うから。
  図解は「地図」タブの図解ライブラリからも見られる。章をまたいで全文検索でき（「2週間」で引くと該当する図が並ぶ）、
  型と科目で絞り込める。会話しなくても体系をつかめる場所として置いている。
- assistant の発話は本文とカードの**順序**を保って保存する（`meta.segments`）。AI は図を出してから「この表の急所は」と続けるため。
- 課金: 第1章は無料（累計80ターン）。第2章以降は Pro 月額（月800ターンのフェアユース）か会話パック（100 / 300回、買い切り）。
  RevenueCat の `app_user_id` = 匿名ID。Webhook で D1 の plan / turn_balance を更新。
- 原価の天井: サーバ側の `GLOBAL_DAILY_TURN_CAP`（既定 3000ターン/日 ≒ ¥6,000/日）。超えると 503 → アプリは「混雑中」表示。

## ローカルで動かす
```
# API（別ターミナル）
cd ~/private/takken-talk-api && npm run migrate:local && npm run dev
# アプリ（シミュレータ）
flutter run --dart-define=API_BASE=http://localhost:8787
```
`ANTHROPIC_API_KEY` が無いとサーバはモック台本で応答する（出題・採点・進捗は本物）。

## 本番までに人手が要ること（チェックリスト）
- [ ] Anthropic Console で API キー発行（console.anthropic.com）→ `wrangler secret put ANTHROPIC_API_KEY`。Console 側で月の Spend limit（例 ¥30,000）も設定。
- [ ] Cloudflare（nullstead アカウント）で `wrangler d1 create takken-talk` → `database_id` を wrangler.toml に反映。API トークン（Workers Scripts:Edit, D1:Edit, Account Settings:Read）を GitHub リポジトリ Secrets `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` に登録 → push でデプロイ。
- [ ] App Store Connect にアプリ作成（Bundle ID `jp.pairof.takken.talk`）。App 内課金: 自動更新 `jp.pairof.takken.talk.pro.monthly`（¥1,480想定）、消耗型 `…pack100`（¥480）、`…pack300`（¥1,180）。
- [ ] RevenueCat にプロジェクト作成 → Public API key を `--dart-define=RC_KEY=appl_...` でビルド。Offering `default` に上記3商品。Webhook URL `https://<worker>/webhooks/revenuecat`、Authorization ヘッダの値を `wrangler secret put REVENUECAT_WEBHOOK_SECRET`。Entitlement `pro`。
- [x] nullstead.com に `/apps/takken-talk`（サポート）と `/apps/takken-talk/privacy` を公開済み。
- [ ] Firebase コンソールで iOS アプリ `jp.pairof.takken.talk` が ichinomiya-apps に登録済みか確認（create_app.sh が登録している）。
- [ ] ASC の App Privacy: 「ユーザーコンテンツ（その他のユーザーコンテンツ）」「使用状況データ」「診断」= アプリ機能・分析、ユーザーに紐付かない（匿名ID）。

## iPad
`TARGETED_DEVICE_FAMILY = "1,2"` で iPad も対象。本文は `Readable`（最大680pt）で中央に寄せ、
iPad で1行が長くなりすぎないようにしている。提出には iPad 13インチのスクリーンショットが要る
（無いと審査提出が 409 `SCREENSHOT_REQUIRED.APP_IPAD_PRO_3GEN_129` で弾かれる）。

## スクリーンショット
`./tool/screenshots.sh` で撮る（`API_BASE` 環境変数でAPIの向き先を変えられる。既定はローカル）。
`integration_test/screenshots_test.dart` が画面を進め、シミュレータの tmp に置くマーカーを見て
シェル側が `xcrun simctl io screenshot` で撮る（doremi_scan と同じ方式）。

**掲載用は本番APIに向けて撮り直すこと。** APIキーが無いとサーバーがモックの定型文を返すので、
会話の中身が掲載に使えない。デプロイ後に `API_BASE=https://<worker> ./tool/screenshots.sh` で撮る。
