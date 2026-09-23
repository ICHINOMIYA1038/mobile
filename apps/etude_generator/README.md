# エチュードメーカー (etude_generator)

即興演劇（エチュード・インプロ）の練習用お題を、人数・ジャンル・時間から生成する iOS アプリ。
5ジャンル×200本＝1000本のお題を `lib/data/etude_themes.dart` に同梱し、役ごとの目的と秘密、
振り返りの問い、場面の「種明かし」まで持つ。登録不要・課金なし。広告は実演中と振り返り画面のみ。

## 構成

| ファイル | 役割 |
| --- | --- |
| `lib/main.dart` | 画面すべて（タイトル → 生成 → 役引き → 実演 → 振り返り、お気に入り） |
| `lib/data/etude_themes.dart` | お題データ（生成物ではなく手書き。1000件） |
| `lib/data/prompt_generator.dart` | ジャンルで絞って1件選び、人数ぶんの役を切り出す |
| `lib/data/favorites_repository.dart` | お気に入りの保存（SharedPreferences） |
| `lib/data/ad_service.dart` / `lib/ui/widgets/ad_banner_slot.dart` | AdMob。UMP 同意 → 初期化。バナーはスロット幅で読み込む |
| `lib/theme/app_colors.dart` | ライト/ダークの色トークン |

設計上の約束:

- 役を引く画面には広告を出さない（他人に見せてはいけない内容が映る）。`test/no_ads_during_activity_test.dart` が検証する
- 共有文に `prompt.secret` を含めない。`test/share_privacy_test.dart` が検証する
- 実演タイマーは終了予定時刻から計算する（ティックを数えるとスリープ中に止まる）。`clock.now()` を使い、テストで時間を進められる

## 開発

```sh
flutter analyze
flutter test      # 157件
flutter run
```

## 審査・リリース

- [docs/app-store-submission.md](docs/app-store-submission.md) — 提出手順・審査メモ・提出履歴
- [docs/store-listing.md](docs/store-listing.md) — ストア掲載文（ASC 側が正、こちらは控え）
- [docs/privacy-policy.md](docs/privacy-policy.md) — 公開ページ https://nullstead.com/apps/etude/privacy の原稿
- リポジトリルートの `ios-app-review-submission.md` — 署名・アップロード手順（全アプリ共通）
