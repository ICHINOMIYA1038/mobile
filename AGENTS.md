# mobile（Flutter アプリ群）

このリポジトリで作業するすべてのエージェント（hermes・Claude Code など）向けの指示書。**このファイルが正本**で、`CLAUDE.md` はこのファイルを読み込むだけ。アプリの所在・鍵（App Store Connect の API キーなど）・事業全体の方針は台帳（Mac mini `~/ledger`、skill `app-ledger`）にある。iOS のリリース手順と落とし穴は `.claude/skills/ios-release/SKILL.md`（Claude Code 以外のエージェントも、このファイルを手順書として読んでよい）。

個人の Flutter アプリ群のモノレポ（GitHub `ICHINOMIYA1038/mobile`、default branch `main`）。
セットアップ・構成の詳細は [README.md](README.md)、共通資料の一覧は [docs/README.md](docs/README.md)。

## 構成

- `apps/<app>/` — 1アプリ1ディレクトリの独立した Flutter プロジェクト。依存解決はルートの
  pub workspace（melos）で1本。`melos bootstrap` はルートで、`flutter run` / `flutter test` はアプリごと
- `packages/` — 2本以上で実際に使うコードだけ（今は `app_insights` = Analytics / Crashlytics）。先回りで共通化しない
- `scripts/create_app.sh` 新規アプリ作成 / `scripts/check_all.sh` 全アプリの analyze + test /
  `scripts/asc/` App Store Connect API（`asc.py` 状態一覧、`attach_submit.py` 添付〜審査提出、`search_rank.py` 検索順位）
- 関連する別リポジトリ: `~/private/takken-talk-api`（takken_talk のサーバー）、`~/private/doremi-omr`（doremi_scan の OMR サーバー）、
  `~/private/nullstead/web`（nullstead.com の LP・プライバシーページ。`git push origin main` で GitHub Actions がデプロイ。
  アプリ一覧データは `apps/homepage/src/lib/data/apps.ts`）

## スコープ: iOS 優先

- 作業・提案・次のアクションは iOS（App Store）だけにする。Google Play / Android（ストア掲載、Play 用スクショ、
  AdMob の Android 広告ユニット、`tool/upload_to_play.py` 等）は、頼まれない限りやらないし提案もしない
- iOS 専用の実装（SoundAnalysis、ARKit、Swift のネイティブコード）は採用してよい

## 新しいアプリ

- 必ず `./scripts/create_app.sh <name> <bundle id>` で作る（Bundle ID は `jp.pairof.*`）。手で `flutter create` した場合や
  古いブランチでは、スクリプトがやっている次の2点が入っているか確認する
  - `ios/Runner/Info.plist` の `CFBundleDevelopmentRegion` = `ja_JP`、`CFBundleLocalizations` = `[ja]`
    （無いとストアの「言語」が英語表示になる。ASC のプライマリ言語では直らない、バイナリ側の設定）
  - iOS の最低ターゲットは **15.0**（pbxproj / Podfile / AppFrameworkInfo。未満だと ITMS-90068 警告）
- 初回提出までに作るもの: `docs/store-listing.md`（ポジショニング・キーワード・ストア文言。雛形は
  `apps/takken_simple/docs/store-listing.md`）、`docs/app-store-submission.md`、プライバシーポリシー
  （計測項目は [docs/analytics.md](docs/analytics.md)）
- **iPad のスクリーンショットは必須**: `TARGETED_DEVICE_FAMILY` に iPad が含まれる限り ASC が要求する。
  iPhone 専用にするのでなければ iPhone / iPad 両方を撮る。作り方は [docs/screenshot-guidelines.md](docs/screenshot-guidelines.md)
  （`tool/screenshots.sh` → fastlane `frameit`）

## 各アプリの資料

- 提出済みのアプリには `apps/<app>/docs/app-store-submission.md` がある（審査履歴・却下理由・直したもの・未対応の項目）。
  アプリを触る前にまずこれを読む。ストア文言の控えは `docs/store-listing.md`
- 定期メンテ（月1回目安の監査 → 修正 → 提出、季節要因、SKAdNetwork、署名の作り直し）は
  [docs/maintenance.md](docs/maintenance.md) の手順で回す
- ブラウザ操作が要る作業（GA4 リンク、プライバシー申告、AdMob）は [docs/console-runbook.md](docs/console-runbook.md)

## リリース・審査提出

- ビルド番号更新 → ビルド → アップロード → 審査提出 → 承認後の配信確認は `ios-release` skill（`.claude/skills/ios-release/SKILL.md`）の手順で
- アップロード・`fastlane ios upload_metadata` / `submit_review`・`attach_submit.py`・`asc.send()` での書き込みは
  App Store Connect に実際に反映される。ユーザーが頼んだ範囲を超えて実行しない
- API キー・パスワード・署名鍵の値をリポジトリに書かない。置き場所は `~/.appstoreconnect/private_keys/` と
  `~/.secrets/<用途>/`（Key ID / Issuer ID は `scripts/asc/asc.py` 参照）

## ASO の原則（2026-08 の全アプリ監査から）

- 新規アプリは「競合が少ないニッチ」でないと検索に出てこない。即興演劇（エチュード）や舞台照明（TOMOSHIBI）は
  1位、宅建・化学クイズ・名前診断のような飽和カテゴリは圏外だった。何を作るか決める前に
  `scripts/asc/search_rank.py` で主要キーワードの順位・競合の評価件数を見て、go / no-go の判断材料にする
- スクリーンショットは広告として作る: 全枚に太字のベネフィット見出し、色帯・バッジ、具体的な数字、
  アイコンと同じ背景色（詳細は docs/screenshot-guidelines.md）
- 名前・サブタイトル・キーワードの変更は新バージョンが要る。プロモーションテキストは配信中でも即時に変えられる
- スクショやメタデータに「無料」「第1章は無料」と書かない（ガイドライン 2.3.7 の価格表記として却下された）
- 騒音計・記録系など同種アプリが量産されているジャンルは 4.3(a)（スパム）で却下されやすい。
  コンセプト単位で差別化する（Sound Shield は「部屋の防音診断」に転換して通過）
