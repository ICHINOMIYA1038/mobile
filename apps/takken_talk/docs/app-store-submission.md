# 宅建 1.0.3 の提出準備

2026-11-11 更新。バージョンは1.0.3、ビルド番号は14。App Store Connect へのアップロード・審査提出は未実施。

## 変更内容

- 初回は論点の説明と確認3問で区切り、結果を振り返れる。
- 翌日は直近の誤答・復習期限・未回答の順に3問を選ぶ。同じ日の問題と解答は端末に保存し、途中から再開できる。
- 異なる10問に答えると、自分の記録を使った1日分の学習プランを1回体験できる。再表示では AI を呼び直さない。
- Pro の案内では、解答記録に合わせた学習プランと苦手分析を先に説明する。
- 初回の開始・完了、翌日と7日後の再訪、価格取得、購入開始・キャンセル・失敗を計測する。学習者 ID や会話本文はイベントに含めない。

## 本番へ反映する順番

1. サーバー側の対応を先に反映する。リポジトリは `pairof-shikaku`、ブランチは `feat/takken-study-conversion`。本番 DB のバックアップ後に `0018_study_previews.sql` を適用する。
2. 最新の main に変更を取り込み、アプリのビルド・署名を確認する。
3. 審査提出についてオーナーに確認する。今回の作業ではストア価格を変更していない。

サーバーが古い場合は新しい3問の入口と体験の案内を表示しない。既存の会話・過去問・Pro は使える。

## 更新内容の文案

・短い説明を読んで3問に答える、はじめの学習を追加しました。
・ホームから今日の復習3問に進めるようにしました。途中で閉じても続きから再開できます。
・10問に答えると、自分の記録を使った1日分の学習プランを1回体験できます。
・Pro の内容をわかりやすくしました。

## 確認方法

アプリのディレクトリで `flutter analyze --no-pub` と `flutter test --no-pub` を実行する。

`integration_test/study_conversion_test.dart` は通信をすべてテスト用に置き換え、実際の AI・購入・本番データを使わない。次のコマンドで試し用シミュレーターを指定する。

```sh
flutter drive --driver=test_driver/study_driver.dart \
  --target=integration_test/study_conversion_test.dart \
  -d <試し用シミュレーターのID> --debug --no-pub \
  --dart-define=API_BASE=http://127.0.0.1:9
```

画像の保存先は `STUDY_SCREENSHOT_DIR`。未指定なら `/tmp/takken-conversion-screenshots`。

## 計測の読み方

| イベント | 数えるもの |
|---|---|
| `study_first_started` | 初回3問を始めた学習者。学習者ごとに1回 |
| `study_first_completed` | 初回3問をすべて答えた学習者。学習者ごとに1回 |
| `study_return_d1` / `study_return_d7` | 初回3問を始めた翌日・7日後に再訪した学習者。日本時間で区切る |
| `study_session_completed` | その日の3問をすべて答えた学習者。同じ日の再表示では増やさない |
| `pro_preview_viewed` | 体験プランを表示した回数。再表示も含む |
| `purchase_price_loaded` / `purchase_price_failed` | 対象商品の価格を取得できたか |
| `begin_checkout` | 購入ボタンを押した回数。金額と通貨はストアの値 |
| `purchase_cancelled` / `purchase_failed` | 購入キャンセルと失敗 |

翌日再訪率は、翌日まで観測できた初回開始者だけを分母にする。同じ期間に2日使った人数を、そのまま翌日再訪率と呼ばない。既存利用者の復習は初回体験の人数に含めない。

購入はサーバーに届く RevenueCat の `PRODUCTION` を正とする。テスト購入を集客の成果に含めない。広告流入だけを識別する計測は今回追加していない。
