# 宅建 1.0.3 の審査提出

2026-11-11 更新。バージョン1.0.3・ビルド14を審査に提出し、`WAITING_FOR_REVIEW` を確認した。承認後は自動公開。価格は月額3,000円のまま。

次版1.0.4・ビルド15のコードとテストは [解答後の導線の改善](study-next-step.md) を参照。1.0.4は未ビルド・未提出で、ここに記録した1.0.3とは区別する。

## 変更内容

- 初回は論点の説明と確認3問で区切り、結果を振り返れる。
- 翌日は直近の誤答・復習期限・未回答の順に3問を選ぶ。同じ日の問題と解答は端末に保存し、途中から再開できる。
- 異なる10問に答えると、自分の記録を使った1日分の学習プランを1回体験できる。再表示では AI を呼び直さない。
- Pro の案内では、解答記録に合わせた学習プランと苦手分析を先に説明する。
- 初回の開始・完了、翌日と7日後の再訪、価格取得、購入開始・キャンセル・失敗を計測する。学習者 ID や会話本文はイベントに含めない。

## 本番へ反映する順番

1. サーバー側の対応を先に反映する。リポジトリは `pairof-shikaku`、ブランチは `feat/takken-study-conversion`。本番 DB のバックアップ後に `0018_study_previews.sql` を適用する。
2. 最新の main に変更を取り込み、アプリのビルド・署名を確認する。
3. App Store の審査へ提出する。オーナーは2026-11-11に、現行価格での本番反映と審査提出を了承済み。

サーバーの D1 はバックアップ後に0018を適用済み。[pairof-shikaku PR #11](https://github.com/ICHINOMIYA1038/pairof-shikaku/pull/11) の main への取り込みと自動デプロイが成功し、公開 API の新しい項目も確認した。アプリの変更は [mobile PR #56](https://github.com/ICHINOMIYA1038/mobile/pull/56) で main に取り込んだ。

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

2026-11-11 の確認結果：静的解析は問題なし、アプリのテスト841件と iOS シミュレーターでの通し確認が成功。確認画像は `screenshots/conversion/` に保存した。画像の解答記録はテスト用のデータ。

1.0.3・ビルド14の公開用アーカイブを作成し、既存の配布用証明書とプロファイルで署名して書き出した。IPA は `build/ios/ipa/takken_talk.ipa`。署名、バージョン、ビルド番号、本番 API への接続設定、通常の起動ファイルを確認した。2026-11-11 02:51 JST にアップロード成功。更新内容を日本語で保存し、既存の説明文・キーワード・iPhone 8枚と iPad 5枚の画像は引き継いだ。

## 審査の状態（2026-11-11 JST）

- 提出時刻: 02:57 JST
- App Store Connect のアプリ ID: `6816080810`
- バージョン ID: `0654b412-a0cc-42f7-94aa-d5cbb1268ab9`
- ビルド ID: `3bf2d09c-d3b6-4dd9-a355-d9883103eab5`（1.0.3・14、`VALID`）
- 審査提出 ID: `19fdf319-930c-4699-bff9-631adbe3b6ad`
- 提出後の状態: `WAITING_FOR_REVIEW`
- 公開方法: `AFTER_APPROVAL`（承認後に自動公開）

承認後は [国内ストアの Lookup API](https://itunes.apple.com/lookup?id=6816080810&country=jp) で、1.0.3が配信されていることを確認する。審査待ちの時点では、公開済みと扱わない。

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
