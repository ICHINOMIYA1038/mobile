# ネタガチャ (neta_gacha)

配信者・VTuber 向けの雑談ネタ／お題ガチャ。配信のシチュエーション（オープニング・初見さん向け・
常連さん向け・ゲーム実況つなぎ 等）を選んでノブをひねると、お題がカードで出る。
お気に入り・カスタムお題・テーマ非表示（恋愛・政治など）・配信前リマインダー・トークタイマー・共有。
登録不要・無料。広告は抽選画面のバナーと、5回に1回の全画面広告のみ。

## 構成

| ファイル | 役割 |
| --- | --- |
| `lib/logic/roulette_controller.dart` | プール構築（同梱＋カスタム、テーマ・履歴で除外）→ 抽選 → 履歴 → 全画面広告の順番管理 |
| `lib/data/*_repository.dart` | お気に入り・履歴（直近55件）・カスタムお題・非表示テーマ（SharedPreferences） |
| `lib/data/notification_service.dart` | 毎日同じ時刻の1件を `matchDateTimeComponents: time` で予約。起動時にも予約し直す |
| `lib/data/ad_service.dart` | AdMob（UMP 同意 → 初期化）。全画面広告は事前読み込みし、画面側が演出後に表示 |
| `assets/prompts/*.json` | お題データ（7シチュエーション × 140本） |

## 開発

```sh
flutter analyze
flutter test
flutter run
```

## 審査・リリース

- [docs/app-store-submission.md](docs/app-store-submission.md)
- [docs/store-listing.md](docs/store-listing.md)（ASC 側が正、こちらは控え）
- リポジトリルートの `ios-app-review-submission.md`
