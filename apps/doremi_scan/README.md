# ドレミふりがな (doremi_scan)

楽譜を撮ると音符にドレミのふりがなを付ける iOS アプリ。対象は童謡・保育曲・初級ピアノ。
認識はクラウド（Cloud Run 上の Audiveris＋自前の補助モデル、`~/private/doremi-omr/omr_service`）で行う。
登録不要・無料・広告なし。**精度は完璧ではない**（全ページのスクショや画面の写真は取りこぼしが多い）ので、
タップ修正と「1〜2段を大きく撮る」誘導で補う方針。2026-09-24 に「現状のまま一旦リリース」と決定。

## 構成

| 場所 | 役割 |
| --- | --- |
| `lib/src/engine/cloud_omr_engine.dart` | サーバー呼び出し。`--dart-define=OMR_API_URL` と `APP_KEY` をビルド時に注入。端末IDヘッダー付き |
| `lib/src/screens/` | ホーム（撮影/選択/履歴）・撮影（ライブ五線検出）・結果（ふりがな表示、修正、清書/原本切替、PDF） |
| `lib/src/services/` | ふりがな配置（`ruby_layout.dart`）、PDF、履歴保存、撮影前チェック |
| `lib/src/engine/native_doremi_engine.dart` | 旧オンデバイス方式（Core ML）。URL 未注入時のフォールバック。実質未使用 |
| `~/private/doremi-omr/omr_service/` | サーバー。`server.py` に鍵認証と日次回数制限（費用上限）がある |

## ビルド・実行

サーバーURLと鍵は必ず `--dart-define` で渡す（リリースビルドは URL 無しだと起動時に例外）。
鍵は `~/.secrets/doremi/app_key.txt`（リポジトリには入れない）。

```sh
flutter analyze
flutter run --dart-define=OMR_API_URL=https://doremi-omr-qiukfzyaga-an.a.run.app --dart-define=APP_KEY=$(cat ~/.secrets/doremi/app_key.txt)
flutter build ipa --release --export-options-plist=build/ios/ipa/ExportOptions.plist \
  --dart-define=OMR_API_URL=https://doremi-omr-qiukfzyaga-an.a.run.app \
  --dart-define=APP_KEY=$(cat ~/.secrets/doremi/app_key.txt)
```

## サーバー費用の上限（2026-09-24）

- Cloud Run: `--max-instances 1 --concurrency 2 --min-instances 0`（同時に動くのは1台まで）
- `server.py`: `X-App-Key` 不一致は 401。日次上限 `DAILY_LIMIT=150`（全端末合計、GCS の `quota/<日付>` で永続）、
  端末別 `DEVICE_DAILY_LIMIT=30`（メモリ内）。超過は 429 で「明日またお試しください」
- 計算上の最大費用: 150回/日 × 約60秒 × 2vCPU/4GiB ≒ 月 ¥9,000 弱
- GCP 予算アラート「doremi-omr 月1万円上限」（50/80/100% でメール）。**請求の自動停止はしていない**
- デプロイ: `gcloud run deploy doremi-omr --account ichiryo108@gmail.com --source omr_service ...`
  （`--account` 必須。既定アカウントは別組織のもので UNAUTHENTICATED になる）

## 審査・リリース

- [docs/app-store-submission.md](docs/app-store-submission.md)
- [docs/store-listing.md](docs/store-listing.md)
- プライバシーポリシー: https://nullstead.com/apps/doremi-furigana/privacy（画像をサーバー送信する旨を明記）
- リポジトリルートの `ios-app-review-submission.md`
