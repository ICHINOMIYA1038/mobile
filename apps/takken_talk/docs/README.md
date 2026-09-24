# 話して受かる宅建（takken_talk）

AIチューターと会話しながら宅建の全11章を学ぶアプリ。企画・設計は `docs/takken-ai-tutor-plan.md`（リポジトリ直下 docs）。
バックエンドは別リポジトリ `~/private/takken-talk-api`（Cloudflare Workers + D1 + Claude `claude-sonnet-5`）。

## 仕組み（ざっくり）
- 端末は初回起動で `POST /v1/users` → 匿名IDとトークンを SharedPreferences に保存。ログインなし。
- 章ごとに1本の会話。`POST /v1/chat` に「発言」か「○×カードの回答」を送ると SSE で返答が流れる。
- 出題はサーバのツール `get_next_question`（takken_simple の300問）。カードで答えるとサーバが採点・SM-2で次回出題日を決める。
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
- [ ] nullstead.com に `/apps/takken-talk`（サポート）と `/apps/takken-talk/privacy` を追加（会話内容を Anthropic に送信して処理する旨、サーバ保存、削除方法を明記）。
- [ ] Firebase コンソールで iOS アプリ `jp.pairof.takken.talk` が ichinomiya-apps に登録済みか確認（create_app.sh が登録している）。
- [ ] ASC の App Privacy: 「ユーザーコンテンツ（その他のユーザーコンテンツ）」「使用状況データ」「診断」= アプリ機能・分析、ユーザーに紐付かない（匿名ID）。
