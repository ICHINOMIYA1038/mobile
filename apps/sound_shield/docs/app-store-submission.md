# App Store 提出メモ

このアプリを審査に出すときの手順と、審査員に伝える内容をまとめたもの。
提出のたびにこの文書を上から順に確認すること。Android/Google Playは現時点でスコープ外。

## 0. 提出前チェック（必ず実行）

```sh
flutter analyze
flutter test
```

両方エラーなしになるまで提出しないこと。

## 1. 提出前にやること

| 項目 | 状態 | 場所 |
| --- | --- | --- |
| Bundle ID | 済 | `jp.pairof.sound.shield` |
| アプリアイコン | 済 | `icon/icon.png` / `icon/icon_foreground.png`。アプリ内の
  `LevelGauge`（騒音計ゲージのCustomPainter）を1024×1024でレンダリングして生成
  （`tool/generate_icons.dart`、`dart run flutter_launcher_icons`で反映済み） |
| pubspec の説明文・バージョン | 未確認 | `description`が`flutter create`のデフォルトのまま。
  `version: 1.0.0+1` |
| 広告SDK | 該当なし | 組み込んでいない |
| 課金SDK | 該当なし | アプリ内課金は組み込んでいない |
| マイクの使用許諾説明（iOS） | 済 | `Info.plist`の`NSMicrophoneUsageDescription`に
  「周囲の騒音を計測するためにマイクを使用します。録音データは保存・送信されません。」
  と自然な日本語で記載済み |
| プライバシーマニフェスト（iOS） | 済 | `ios/Runner/PrivacyInfo.xcprivacy`を新規作成
  （`NSPrivacyTracking=false`、収集データなし、直接使用する要申告APIなし。
  Firebase Analytics/Crashlytics分は各SDK自身のマニフェストが申告）。
  Xcodeプロジェクト（`project.pbxproj`）のResourcesビルドフェーズにも追加済み |
| プライバシーポリシーの公開URL | 済 | https://nullstead.com/apps/sound-shield/privacy
  （nullstead.comへデプロイ済み、実際に開けて内容も確認済み） |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com（`docs/store-listing.md`に記載） |
| ストア掲載文（説明・キーワード・カテゴリ） | 済 | `docs/store-listing.md` |
| **Xcodeで Team を確認** | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49`（他アプリと同じチーム）、
  `CODE_SIGN_STYLE = Automatic`設定済み |
| ストア用スクリーンショット | 済 | `./tool/screenshots.sh`で撮影、fastlane `frameit`で
  実機ベゼル付きに合成済み（iPhone・iPad各5枚）。UIを変えたら撮り直すこと |
| **App Store Connect 上の情報入力** | 済 | 下記「5. 提出状況」参照。アプリ作成・全情報入力・ビルド紐付け完了、審査提出待ち |
| **有料アプリ契約・納税・銀行口座（Apple）** | 該当なし | 無料アプリ・IAPなしのため不要 |

## 2. 審査メモ（App Review Information の Notes 欄にそのまま貼る）

```
本アプリはマイクを使って周囲の騒音レベルを計測し、音量の目安・音源の推定・
改善提案を表示するユーティリティアプリです。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【マイクの使用について・重要】
本アプリはマイクを騒音レベルの計測にのみ使用します。音声データは端末内で
リアルタイムに解析されるだけで、録音として保存されることはなく、外部サーバーへ
送信されることも一切ありません。計測が終わると数値化された結果（dB値・周波数帯
ごとのレベル・検出音のラベル等）のみがアプリ内に保持されます。

【音源推定について】
検出音の種類（車・話し声等）の推定にはApple純正のSoundAnalysisフレームワーク
（SNClassifySoundRequest）を使用しており、これもオンデバイスで完結します。
外部のAIサービスや通信は一切使用していません。

【通信・データ収集について】
Firebase Analytics/Crashlyticsによる匿名の利用状況・クラッシュ計測のみ通信が
発生します。計測結果や音声データそのものが送信されることはありません。

【アプリ内課金・広告】
ありません。すべての機能を無料でご利用いただけます。

【動作確認の手順】
1. 起動 → ホーム画面で計測方法（時間を指定 / 止めるまで測定）と時間を選ぶ
2. 「計測を開始」をタップ → マイクの使用許諾ダイアログが表示されたら許可
3. 計測中画面でゲージが振れ、残り時間または経過時間が表示される
4. 計測終了後、結果画面へ自動遷移（Leq/最小/ピーク、ステータス、
   周波数帯・時間推移のグラフ）
5. 結果画面上部のステータスバッジをタップ → 騒音スケール画面（環境省基準の3段階説明）
6. 結果画面下部の「対策を見る」をタップ → 検出音の内訳と改善提案の画面
```

## 3. アプリの暗号化書類

- 標準的な暗号化アルゴリズムのみ（HTTPS等）を使用
- フランスでの配信予定: いいえ
（他アプリと同じ回答。詳細は`ios-app-review-submission.md`参照）

## 4. スクリーンショット

**自動生成できる。手で撮らないこと。** 見出し合成は fastlane `frameit`
（実機ベゼル付き）で行う。詳しい仕組みは
[`docs/screenshot-guidelines.md`](../../../docs/screenshot-guidelines.md)参照。

```sh
./tool/screenshots.sh                                            # iPhone 6.9インチ（1320×2868）
./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad    # iPad 13インチ

# 生スクショを fastlane のロケールフォルダへ配置してから frameit を実行
cp screenshots/*.png ios/fastlane/screenshots/ja/
for f in 01_home 02_measuring 03_result 04_suggestions 05_noise_scale; do
  cp "screenshots_ipad/${f}.png" "ios/fastlane/screenshots/ja/${f}_ipad.png"
done
cd ios && bundle install && bundle exec fastlane ios compose_screenshots
```

`screenshots/` に5枚書き出される。撮る内容は `integration_test/screenshots_test.dart`。
`SoundMeterService`のMethodChannel/EventChannel（マイクのネイティブブリッジ）を
このテスト内でモックし、固定のダミー計測結果を使うことで、実機マイクなしでも
シミュレータで安定して撮影できるようにしている。

1. `01_home` — ホーム画面（ゲージと計測方法・時間の選択）
2. `02_measuring` — 計測中画面（ゲージが振れている状態、モックのliveDbStream値を表示）
3. `03_result` — 結果画面（Leq/最小/ピーク、ステータスバッジ、周波数帯・時系列グラフ）
4. `04_suggestions` — 改善提案画面（検出音の内訳と対策）
5. `05_noise_scale` — 騒音スケール画面（環境省基準の3段階説明、計測値のマーカー付き）

見出し・サブ見出しの文言や背景色は `ios/fastlane/screenshots/Framefile.json` を編集する。
完成品は `ios/fastlane/screenshots/ja/*_framed.png`。
`bundle exec fastlane ios upload_metadata` でApp Store Connectへアップロードできるが、
**実際に反映されるため実行前に必ずユーザーへ確認すること**。

生成物（`screenshots/` `screenshots_ipad/` `ios/fastlane/screenshots/ja/*_framed.png`
`ios/fastlane/frame_assets/fonts/`）は `.gitignore` 済み。UI を変えたら撮り直すこと。

## 5. 提出状況（2026-08-26時点）

- コード・アイコン・スクリーンショット・ストア掲載文・プライバシーポリシーページ（公開確認済み）・
  App Store Connect上の全情報入力・ビルド1.0.0(1)のアップロードと紐付け・審査提出、
  すべて完了。**現在「1.0 審査待ち」ステータス**（審査には最大48時間、完了するとメール通知）
- Gitへのコミットはまだ（`git status`で`??`表示のまま、ユーザーの明示的な指示待ち）
- 次回このアプリを更新する場合は、ビルド番号（`pubspec.yaml`の`version:`末尾の`+N`）を
  上げてから`flutter build ipa --release`→`xcrun altool --upload-app`の手順を繰り返すこと
