# ネタメーカー (neta_maker)

名前を入れるだけで「二つ名」「前世」「脳内」をジョーク診断する iOS アプリ。同じ名前なら
いつも同じ結果（決定的生成）、「もう一度」でだけ別の結果。登録不要・無料、広告は結果画面のみ。

## 構成

| ファイル | 役割 |
| --- | --- |
| `lib/logic/maker_engine.dart` / `seeded_random.dart` | 名前＋nonce から決定的に乱数を作り、語彙バンクから文を組み立てる |
| `lib/data/generators/*_bank.dart` | 語彙バンク（二つ名・前世・脳内）。`test/vocabulary_lint_test.dart` が悪口・重複・不成立な後半を弾く |
| `lib/ui/screens/*` | ホーム → 入力 → 結果。広告は結果画面だけ（`test/no_ads_during_activity_test.dart`） |
| `lib/data/ad_service.dart` | AdMob（UMP 同意 → 初期化、非パーソナライズ、ATT 非要求） |

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
