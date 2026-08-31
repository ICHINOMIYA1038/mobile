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
| 課金SDK | 該当なし | アプリ内課金は組み込んでいない(2026-08-28: まず無料で様子を見る方針。将来入れる場合は `docs/concept-v2.md` §3 の設計を参照) |
| カメラの使用許諾説明(iOS) | 済(v1.1.0〜) | `NSCameraUsageDescription`: ARマップの位置追跡用。映像は保存・送信しない旨を記載 |
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

## 2. 審査メモ（App Review Information の Notes 欄にそのまま貼る）— v1.1.0

```
本アプリは v1.0 から内容を全面的に変更し、「部屋の防音性の診断」に特化したアプリになりました
(v1.0 は Guideline 4.3(a) のご指摘を受け、コンセプトを見直しました)。

【アプリの目的・独自性】
一般的な騒音計(dBメーター)とは異なり、以下を独自実装しています。
1. 内見診断: 部屋の中央/窓際/隣室側の計測に加え、壁のノック音のスペクトル重心と減衰時間、
   手叩きの残響時間(RT60換算)を解析し、窓・壁・ドアの弱点と壁の重さを推定して防音スコアを算出
2. 音の侵入マップ: ARKit のワールドトラッキングで端末位置を追跡しながらレベルを記録し、
   空間上にヒートマップとして表示
3. 対策シミュレーター: オクターブバンド別の減衰量テーブルを用いて、対策ごとの予測ΔdBと費用を算出
4. 対策の Before/After 検証
すべてオンデバイスで完結し、テンプレートや購入したコードは使用していません。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【アプリ内課金・広告】
ありません。すべての機能を無料でご利用いただけます。

【カメラの使用について】
ARマップで端末の位置を追跡するためだけに使用します。映像は保存・送信しません。
ARKit のワールドトラッキング非対応端末では、対応していない旨を表示します。

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
1. 起動 → ホームの「内見診断」→ 物件名を入力して「診断を始める」
2. 5ステップを順に実施(各ステップは「飛ばす」も可)。計測ステップは15秒、
   ノック/手叩きは「待機して叩く」を押してから1回叩く
3. 結果画面: 防音スコア・等級・弱点・壁の推定 → 「効く対策を予測する」で対策シミュレーター
4. ホーム「騒音計」→「計測を開始」→ 結果(周波数帯・時間推移) → 「効く対策を予測する」
5. シミュレーターで「この対策を試す」→ ホーム「対策の効果を検証」に記録され、
   「対策後を計測する」で再計測すると実測ΔdBが出る
6. ホーム「音の侵入マップ」→ 「開始」→ 壁・窓に沿って端末を動かす → 「終了して結果を見る」
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

## 5. 提出状況（2026-08-28時点）

- **2026-09-01: v1.1.0 (build 2) を審査提出済み(WAITING_FOR_REVIEW)**。
  却下された1.0の審査提出が UNRESOLVED_ISSUES のまま残っており「A review submission is
  already in progress」で提出に失敗 → Spaceship の `cancel_submission` でキャンセルしてから
  `submit_review` レーンで成功。承認後は自動リリース設定。手順の記録:
  - 実機で内見診断(ノック/手叩き)・校正・自動終了計測をユーザー確認済み
  - スクショ6枚(iPhone/iPad)を撮り直し → `bundle exec fastlane ios compose_screenshots`
  - ストア掲載文v2は `ios/fastlane/metadata/`(deliver形式)に転記。カテゴリは
    LIFESTYLE/UTILITIES、審査メモは `metadata/review_information/notes.txt`
  - `Info.plist` に `ITSAppUsesNonExemptEncryption=false` を追加(輸出コンプライアンス省略)
  - `flutter build ipa --release` → `xcrun altool --upload-app`(API キー 3URMU94JK9)
  - ビルド処理完了を待って `bundle exec fastlane ios submit_review version:1.1.0 build:2`
    (メタデータ+スクショ反映・ビルド紐付け・審査提出・承認後自動リリースまで一括)
  - ARマップのスクショは今回未掲載(シミュレータで撮れないため)。次回更新で実機撮影分を追加

- **2026-08-27〜28: iOS 1.0 却下（Guideline 4.3(a) Design - Spam）**。Submission ID
  `043650f1-5ac4-4532-aafb-0bde7bcd3ce0`。「他の開発者のアプリとバイナリ・メタデータ・コンセプトが
  類似」との指摘。騒音計アプリ自体が飽和ジャンルのため、コンセプト単位で弾かれた可能性が高い
- 対応方針は下記「6. 4.3(a) 却下への対応」参照

### 2026-08-26時点の記録

- コード・アイコン・スクリーンショット・ストア掲載文・プライバシーポリシーページ（公開確認済み）・
  App Store Connect上の全情報入力・ビルド1.0.0(1)のアップロードと紐付け・審査提出、
  すべて完了。**現在「1.0 審査待ち」ステータス**（審査には最大48時間、完了するとメール通知）
- Gitへのコミットはまだ（`git status`で`??`表示のまま、ユーザーの明示的な指示待ち）
- 次回このアプリを更新する場合は、ビルド番号（`pubspec.yaml`の`version:`末尾の`+N`）を
  上げてから`flutter build ipa --release`→`xcrun altool --upload-app`の手順を繰り返すこと

## 6. 4.3(a) 却下への対応（2026-08-28）

Apple側は「コンセプトが既存アプリと似ている」と見ている。テンプレ購入・コード流用は一切ない
（全コード自作、他アプリとの共通部は`app_insights`パッケージのみ）ので、差別化点を
App Reviewの返信で明示し、あわせて機能面でも差別化を強める。

1. App Reviewページからの返信（差別化点を具体的に）
   - 音源推定（SoundAnalysis / SNClassifySoundRequest）→ 音源種別ごとの改善提案という、単なる
     dBメーターにはない独自フロー
   - 環境省「騒音に係る環境基準」を基にした日本向けの3段階スケールと実例図
   - 周波数帯別レベル・時間推移グラフ
   - 全コード独自実装、テンプレ・購入コード不使用、広告なし、他アカウントでの類似提出なし
2. 返信で通らなかった場合: 機能追加して再提出（候補: 計測履歴・場所メモ、レポート共有、
   静音時間帯の自動検出など、「騒音の原因特定と対策」に寄せた機能）
