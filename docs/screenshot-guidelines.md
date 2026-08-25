# ストアスクリーンショットの作り方

2026-08-19、宅建・化学クイズ・名前診断の各カテゴリで実際にダウンロードされているアプリ
（評価4.8前後・レビュー数が桁違いに多いもの）のスクリーンショットを、自分たちのアプリ
（`takken_simple` / `neta_maker` / `etude_generator`）と比較した結果をまとめたもの。
新しいアプリを審査に出す前に、この文書のチェックリストを一度通すこと。

## わかったこと: 売れているアプリは「スクショ=広告」として作っている

比較対象:

| アプリ | 評価件数 | 特徴 |
|---|---|---|
| 宅建 過去問 2026 - 独学TODAY | 4.2万件・4.8 | 色帯+白抜き太字見出しを**5枚全部**に配置 |
| 赤ちゃん名づけ（400万人利用） | 6,625件・4.5 | ピンクのバッジ風吹き出しに具体的な数字を詰め込む |
| ケミマスター（化学クイズ、開発者は個人） | 51件・4.8 | 端末を斜めに浮かせた構図＋ベネフィット見出し |

一方、自分たちのアプリは：

- `takken_simple`: 1枚目だけ見出しあり、2〜5枚目は見出しなしの素のスクリーンショット
- `neta_maker`: 5枚とも見出しが一切ない、素のアプリ画面そのまま
- `etude_generator`: アプリ内デザイン（ホーム画面）自体は凝っているが、それは外付けの
  訴求コピーではなく、5枚を通じたベネフィット訴求にはなっていない

UIの出来不出来ではなく、**「1枚ごとに何が嬉しいアプリかを一言で言い切っているか」**が
ダウンロードされるアプリとされないアプリの分水嶺になっている。

## 売れているアプリに共通する4要素

1. **全スクリーンショットに見出しがある** — 1枚目だけでなく5枚あれば5枚全部に、その画面で
   伝えたいベネフィットを大きな太字で書く。1枚ごとに違うベネフィットを担当させ、5枚で
   完結したセールスコピーにする
2. **色帯・バッジで視線誘導** — 見出しをただ乗せるのではなく、色付きの帯やリボン・円形バッジの
   中に入れて「保証書」「合格印」のような信頼感を演出する
3. **具体的な数字を見せる** — 「10年分」「300,000種」「400万人」など、抽象的な訴求でなく
   数字で殴る。レビュー数がなくても「全300問」「全17単元・510問」のような収録量の数字は
   最初から使える
4. **アイコンと同じ配色でスクショの背景を統一** — ブランドの一貫性が一目でわかる

## 実装方法: fastlane `frameit`（2026-08-21〜、旧`tool/store_previews.sh`から移行）

以前はアプリごとに`tool/store_previews.sh`（ImageMagickでベゼルなしの背景+見出し合成）
を持っていたが、実機ベゼル付きスタイルに統一するため fastlane `frameit` に置き換えた。
**新しいアプリのスクショもこの方式で作ること。**`tool/store_previews.sh`自体は各アプリの
`tool/`から削除済み（撮影用の`tool/screenshots.sh`はそのまま残す）。

仕組み:

- `tool/screenshots.sh`（変更なし）でシミュレータの生スクリーンショットを撮る
- 生スクショを `ios/fastlane/screenshots/ja/` に配置する（iPhone・iPad両方を同じ
  フォルダに置いてよい。frameitが解像度からデバイス種別を自動判定する。iPadは
  ファイル名に`_ipad`サフィックスを付けて、iPhone版と同じ`filter`にマッチさせる）
- `ios/fastlane/screenshots/Framefile.json` に、ファイル名ごとの見出し（`title`）・
  サブ見出し（`keyword`）・背景色・フォントを定義する
- `ios/fastlane/frame_assets/background.png` にブランドカラーの単色背景画像を置く
  （`magick -size 400x400 "xc:#ブランド色" background.png` で作れる。frameitが
  スクリーンショットのサイズまで自動で引き伸ばす）
- `cd ios && bundle install && bundle exec fastlane ios compose_screenshots` を
  実行すると、実機ベゼル＋見出し・サブ見出しを合成した `*_framed.png` が
  `ios/fastlane/screenshots/ja/` に生成される

新しいアプリで使う手順:

1. `scripts/create_app.sh` で新規アプリを作った時点で `ios/Gemfile` /
   `ios/fastlane/{Appfile,Fastfile}` は自動生成済み。`ios/fastlane/frame_assets/`
   と `ios/fastlane/screenshots/Framefile.json` だけ新規に作る
2. 背景色はそのアプリのアイコン配色に合わせる（要素4）。既存アプリの例は
   `apps/neta_gacha/ios/fastlane/screenshots/Framefile.json` 等を参照
3. `Framefile.json`の`data[]`で、画面ごとに異なるベネフィット一言を`title`/`keyword`
   に書き分ける（要素1）。`filter`は`screenshots/ja/`内のファイル名の一部と一致させる
4. 収録数・問題数などレビューに依存しない具体的な数字があれば見出しに入れる（要素3）
5. `./tool/screenshots.sh` で撮影 → 生スクショを`ios/fastlane/screenshots/ja/`へ配置
   → `bundle exec fastlane ios compose_screenshots` を実行
6. できあがった `*_framed.png` を目視確認し、`bundle exec fastlane ios upload_metadata`
   でApp Store Connectへアップロードする（メタデータ・スクショのみ。ビルド・価格帯・
   輸出コンプライアンスは触れない設定にしてある）。**このコマンドは実際にApp Store
   Connectへ反映されるため、実行前に必ずユーザーへ確認すること**

既知の制約（2026-08-21時点のfastlane 2.238.0）:

- iPad Pro 13インチ(M4)の実機解像度2064x2752はfastlaneの端末データベースにまだ無く、
  そのままでは"Unsupported screen size"で失敗する。Fastfileの`compose_screenshots`
  レーンが、ファイル名に`_ipad`を含む画像を自動的に2048x2732へリサイズしてから
  frameitに渡す処理を入れているため、通常は意識しなくてよい
- fastlane `snapshot`（シミュレータ自動操作でのスクショ撮影）はXCUITest専用で、
  Flutterの`integration_test`を駆動する方法が存在しない
  （[fastlane/fastlane#22040](https://github.com/fastlane/fastlane/issues/22040)は
  Flutter対応を"not planned"でクローズ済み）。撮影は引き続き`tool/screenshots.sh`
  （シミュレータのmarker-file pollingでのスクショ撮影）を使う

## まだやれていないこと（次の改善候補）

- バッジ・リボン風の装飾（今は実機ベゼル+テキストのみで、円形バッジや帯の背景色分けはない）
- 具体的な数字の強調表示（大きいフォント・色分けで数字だけ目立たせる、等）
- `neko_chemistry` / `tomoshibi` / `korokoro_slope` / `sound_shield` はまだ
  `ios/fastlane/screenshots/`の中身（Framefile.json・生スクショ）が無い
  （Gemfile/Fastfileのひな形のみ配線済み）。審査提出が近づいたアプリから順に作ること

これらは審査提出をブロックする話ではないので、余裕があれば試す程度でよい。
まずは全スクリーンショットに見出しを入れることを優先する。
