# 猫と学ぶ高校化学 (neko_chemistry)

高校化学（化学基礎・化学）を一問一答で学ぶ iOS アプリ。全17単元・510問、苦手問題の自動記録、
ブックマーク、用語集・元素周期表・暗記カード、猫の相棒のきせかえ、連続学習日数とバッジ。
登録不要・無料・広告なし・分析なし（データは端末内のみ）。

## 構成

| ファイル | 役割 |
| --- | --- |
| `lib/logic/quiz_controller.dart` | 出題（単元・出題数・苦手・ブックマーク）、選択肢のシャッフル、回答記録、セッション完了処理 |
| `lib/data/progress_repository.dart` | 進捗（苦手・ブックマーク・単元別統計・学習カレンダー・連続日数・バッジ）。書き込みは直列化 |
| `lib/data/notification_service.dart` | 毎日同じ時刻の復習リマインダー1件（起動時にも予約し直す） |
| `lib/logic/cat_type_diagnosis.dart` | 猫タイプ診断 |
| `assets/questions.json` | 問題データ（17単元 × 30問） |

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
