# App Store 提出メモ（ドレミふりがな）

署名・アップロード・API での提出はリポジトリルートの `ios-app-review-submission.md`。

## 提出前チェック

```sh
cd apps/doremi_scan
flutter analyze
# テストは無い（2026-09-24 時点）。実機で「撮影→認識→修正→PDF」を一度通す
```

## 提出前にやること

| 項目 | 状態 | 備考 |
| --- | --- | --- |
| Bundle ID | 済 | `jp.pairof.doremiScan`（ASC API で 2026-09-24 に登録。名前 "Doremi Furigana"） |
| ASC のアプリ作成 | 済 | 2026-09-24 に Chrome（Claude in Chrome）で作成。App ID `6815585097`、SKU `doremi_furigana`。API ではアプリ作成不可。ダイアログの select は React 管理で form_input が効かず、JS で value を設定して change を発火させた |
| 表示名 | 済 | `CFBundleDisplayName = ドレミふりがな`。旧「ドレミスキャン」は競合と同名のため変更 |
| iOS 15.0+ / 縦固定 / 輸出コンプライアンス | 済 | 2026-09-24 |
| プライバシーポリシー | 済 | https://nullstead.com/apps/doremi-furigana/privacy（画像のサーバー送信・匿名端末ID・回数上限を明記） |
| App のプライバシー申告 | 済 | 「データを収集しません」で公開（2026-09-24）。Apple の定義では、送信後すぐ処理して破棄する画像は「収集」に当たらない。匿名端末IDもインスタンスのメモリ内で当日限り。ポリシーページには送信の事実を明記済み |
| 広告 / 課金 / 分析 | なし | SDK 未組込 |
| サーバー費用上限 | 済 | README「サーバー費用の上限」参照。Cloud Run max-instances 1、日次150回、予算アラート¥10,000 |
| スクリーンショット | 済 | iPhone 6.9インチ・iPad 13インチ 各4枚。`tool/screenshots.sh`（本番サーバーで実認識）→ `fastlane ios compose_screenshots` → `fastlane ios upload_screenshots`。iPad は対応端末に含めている限り必須（無いと提出時に 409） |
| 審査メモ | 下記 | |

## 審査メモ（App Review Information の Notes）

```
ドレミふりがな is a Japanese app that photographs sheet music and adds "doremi" (solfège) readings above each note, for nursery-song and beginner-piano players.

How to test (no account needed):
1. Launch → tap 「写真を選ぶ」 and pick any sheet-music image, or tap 「楽譜を撮る」 and photograph printed sheet music (nursery songs / beginner piano work best).
2. Recognition runs on our server (Google Cloud Run, Tokyo) and takes 20–60 seconds. The result shows the notes with doremi readings; tap a reading to correct it, tap an empty spot to add a missed note.
3. 「PDF」 exports a printable score with readings.

Privacy: the score image is uploaded only for recognition and discarded after processing; no account, no ads, no IAP, no analytics SDK. A random per-device ID is sent only to enforce a daily usage limit (server-cost cap). Details: https://nullstead.com/apps/doremi-furigana/privacy

Limits: to keep server cost fixed there is a daily cap (per device and overall). If you hit it during review, please contact us and we will raise it.
```

## 提出状況

| 日付 | 内容 |
| --- | --- |
| 2026-08-28〜09-07 | 開発（クラウド OMR、清書、超解像、第2エンジン）。詳細はメモリ/`doremi-omr` |
| 2026-09-24 | 精度不足で一度は保留 → 「現状のまま一旦リリースし費用上限だけ掛ける」に方針転換。サーバーに鍵認証＋日次上限、予算アラート、表示名変更、プライバシーページ公開、Bundle ID 登録 |
| 2026-09-24 18:10 | **1.0(1) 審査提出（WAITING_FOR_REVIEW）**。提出時に不足だった「著作権表記」「コンテンツ配信権」「iPad スクリーンショット」を API/撮影で補って再提出。承認後は自動リリース、価格は無料、配信地域は全175地域 |

