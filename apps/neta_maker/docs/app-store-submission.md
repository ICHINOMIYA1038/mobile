# App Store / Google Play 提出メモ

このアプリを審査に出すときの手順と、審査員に伝える内容をまとめたもの。
提出のたびにこの文書を上から順に確認すること。

## 0. 提出前チェック（必ず実行）

```sh
flutter analyze
flutter test
```

両方エラーなしになるまで提出しないこと。

## 1. 提出前にやること

| 項目 | 状態 | 場所 |
| --- | --- | --- |
| Bundle ID / applicationId | 済 | `jp.pairof.netamaker`（iOS/Androidで統一済み） |
| アプリアイコン | 仮 | `icon/icon.png`・`icon/icon_foreground.png` はプレースホルダー（星のシンプル図形）。本番リリース前にブランド用アイコンへ差し替え、`dart run flutter_launcher_icons` で再生成すること |
| pubspec の説明文・バージョン | 済 | `description` を実際の内容に更新済み（`version: 1.0.0+1` のまま初回提出） |
| 広告SDK（Google AdMob） | 済 | `google_mobile_ads` を組み込み済み。AdMobで「ネタメーカー」(iOS/Android)を登録し、実アプリID・実広告ユニットIDに差し替え済み（2026-08-01）。新規広告ユニットは配信開始まで1時間程度かかる場合がある |
| 課金/アナリティクスSDK | 該当なし | アプリ内課金・分析SDKは組み込んでいない |
| プライバシーマニフェスト（iOS） | 未確認 | `ios/Runner/PrivacyInfo.xcprivacy` の内容が実際のデータ収集方針（トラッキングなし、収集データなし）と合っているか確認すること |
| プライバシーポリシーの公開URL | 済 | https://nullstead.com/apps/neta-maker/privacy （2026-08-01公開）。実体は `~/nullstead/web` の別リポジトリ |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com（`docs/privacy-policy.md` に記載） |
| ストア掲載文（説明・キーワード・カテゴリ） | 済 | `docs/store-listing.md` |
| Androidのリリース署名鍵 | 未 | リリース用の署名鍵をまだ生成していない。`android/key.properties.example` を参考に用意すること |
| **Xcodeで Team を確認** | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49`（etude_generatorと同じチーム）、`CODE_SIGN_STYLE = Automatic`設定済み。実機ビルド・アーカイブ前に一度Xcodeで開いて証明書エラーがないか確認すること |
| ストア用スクリーンショット | 済 | `./tool/screenshots.sh` で撮影済み（6.9インチ 1320×2868、5枚）。UIを変えたら撮り直すこと |
| 起動画面（Launch Image / launch_background） | 済 | `icon/icon.png`（羊皮紙+封蝋アイコン）から書き出し済み。アイコンを変更したら再生成すること |
| **App Store Connect / Google Play Console 上の情報入力** | iOS一部完了 | 下記「6. 提出状況」参照。ビルド未アップロードのため審査提出はまだ |
| **有料アプリ契約・納税・銀行口座（Apple）** | 該当なし | 無料アプリ・IAPなしのため不要 |

## 2. AdMobの本番設定（完了済み）

etude_generator/takken_simpleと同じAdMobアカウントに「ネタメーカー」を登録済み（2026-08-01）。

| | iOS | Android |
| --- | --- | --- |
| アプリID | `ca-app-pub-8691137965825158~5167470264` | `ca-app-pub-8691137965825158~5502512189` |
| バナー広告ユニットID（結果画面バナー） | `ca-app-pub-8691137965825158/8852544345` | `ca-app-pub-8691137965825158/7790478182` |

`ios/Runner/Info.plist`・`android/app/src/main/AndroidManifest.xml`・`lib/data/ad_service.dart`
の3箇所に反映済み。新規に作成した広告ユニットは、配信が始まるまで1時間ほどかかる場合がある
（すぐに広告が表示されなくてもテストIDへの巻き戻し等は不要）。

広告は**常に非パーソナライズ広告**として配信する設定にしているため、ATT（トラッキング許可）ダイアログは表示されない。パートナーでの入札（サードパーティのメディエーション/RTB）は使わずAdMob単独運用とする。

## 3. コンソール入力の下書き

### アプリ情報

- **名前**: ネタメーカー
- **サブタイトル**: 名前を入れるだけ。二つ名・前世・脳内をジョーク診断
- **カテゴリ**: エンターテインメント
- **年齢制限**: 4+ / 全年齢

### App のプライバシー（申告内容）

本アプリはアカウント登録・分析SDKを持たないが、**Google AdMobを組み込んでいるため、SDKが扱う分を申告する必要がある**。

- トラッキング: **なし**（非パーソナライズ広告のみを配信し、ATT も要求していない）
- 収集するデータ:
  - **識別子 → デバイスID**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
  - **使用状況データ → 広告データ**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
- 入力した名前・診断結果は端末内でのみ扱われ、保存も外部送信もされないため申告対象外。

App Store Connect の「App のプライバシー」、Google Play の「データセーフティ」とも上記の内容で申告する。

> AdMobの設定を非パーソナライズから変更した場合、この申告と `docs/privacy-policy.md` の
> 2箇所を必ず揃えること。ずれていると審査で落ちる。

### 審査メモ（App Review Information の Notes 欄にそのまま貼る）

```
本アプリは名前を入力してジョーク診断結果を生成するエンターテインメントアプリです。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【通信・データ収集について】
分析SDKは組み込んでいません。Google AdMobによる広告表示のときのみ通信が発生します。
入力した名前・診断結果は端末内でのみ扱われ、外部へ送信されません。

【広告について】
結果画面にのみ、Google AdMobのバナー広告を表示します。カテゴリ選択画面・名前入力画面
（診断のコア体験部分）には広告を表示しません。常に非パーソナライズ広告として配信するため、
ATT（トラッキング許可）のダイアログは表示していません。

【アプリ内課金】
ありません。すべての機能を無料・無制限でご利用いただけます。

【動作確認の手順】
1. 起動 → ホーム画面で3つの診断（二つ名メーカー/前世メーカー/脳内メーカー）から1つ選ぶ
2. 名前・ニックネームを入力して「診断する」をタップ
3. 結果画面が表示されます（同じ名前を入れると常に同じ結果になります。ここにのみ広告が出ます）
4. 「もう一度」で新しい結果を、「シェア」で結果の共有を試せます
5. 「ホームに戻る」で最初の画面に戻れます
```

## 4. スクリーンショット

`./tool/screenshots.sh` を用意済み（etude_generator と同じ方式）。撮る内容は
`integration_test/screenshots_test.dart` にある。

```sh
./tool/screenshots.sh
```

自動化環境（CI/エージェント経由の非対話シェル）では常駐プロセスとの連携がうまくいかず
`screenshots/` が空になることがある。その場合は開発者本人のターミナルで直接実行すること。

1. `01_home` — ホーム画面（3カテゴリ選択）
2. `02_input` — 名前入力画面
3. `03_result_futatsuna` — 二つ名メーカーの結果画面
4. `04_result_zensei` — 前世メーカーの結果画面
5. `05_result_nounai` — 脳内メーカーの結果画面

## 5. バージョン管理

`pubspec.yaml` の `version: 1.0.0+1` が iOS の `CFBundleShortVersionString` /
`CFBundleVersion`、Android の `versionName` / `versionCode` に反映される。
再提出のたびにビルド番号（`+1` の部分）を上げること。

## 6. 提出状況（2026-08-01時点）

### iOS（App Store Connect）

Apple Developer で Bundle ID `jp.pairof.netamaker` を登録し、App Store Connect にアプリ「ネタメーカー」
を作成済み（Apple ID: `6796881273`）。以下を入力・公開済み:

- スクリーンショット（6.9インチ、5枚）アップロード済み
- プロモーション用テキスト・概要（説明文）・キーワード・サポートURL 入力済み
- サブタイトル入力済み
- コンテンツ配信権（サードパーティ製コンテンツなし）設定済み
- 年齢制限指定アンケート回答済み → 算出結果 **4+**（想定どおり）
- 「Appのプライバシー」申告・公開済み（プライバシーポリシーURL、データタイプ=デバイスID・広告データ、
  いずれも「サードパーティ広告」目的・ユーザーに紐付けないで登録）

**ビルドのアップロードはApp Store Connect APIキー経由で完結できる（2026-08-02確認）:**

```sh
flutter build ipa --release
xcrun altool --upload-app --type ios -f build/ios/ipa/neta_maker.ipa \
  --apiKey 3URMU94JK9 --apiIssuer 1039c5ec-53b4-4125-b857-d5059f3f3e74
```

APIキー（`~/.appstoreconnect/private_keys/AuthKey_3URMU94JK9.p8`、キー名"IPA Upload"、
App Manager権限）は事前に用意済み。Issuer IDは App Store Connect の
「ユーザとアクセス」→「統合」→「App Store Connect API」ページで確認できる。
altoolはアップロード成功後の検証ステップで409エラーを返すことがあるが、
実際のビルドアップロード自体は成功しているため無視してよい（TestFlightページでビルドの
「処理中」ステータスを確認すること）。

2026-08-02に Version 1.0 (Build 1) をこの方法でアップロード済み。あわせて以下も完了済み:

- 「サインインが必要です」チェックを解除（本アプリはログイン不要のため）
- 審査メモ入力・保存済み（本ドキュメント「3. コンソール入力の下書き」の内容）
- 連絡先情報入力・保存済み（一ノ宮 綾平 / +818083836352 / ichiryo108@gmail.com）
  — 電話番号は国コード付き・記号なしの形式（`+818012345678`）でないと保存エラーになる

2026-08-03、ビルド処理完了後に以下を完了し、審査へ提出済み（ステータス: **審査待ち**）:

- 配信ページの「ビルド」セクションでビルド1を選択
- 輸出コンプライアンス（アプリの暗号化書類）: 標準的な暗号化アルゴリズムのみ／フランスでの配信予定なし、を選択
  （フランス配信を「はい」にすると別途輸出コンプライアンス書類の提出が必要になるため、「いいえ」を選択）
- 著作権表記欄: `© 2026 Ryohei Ichinomiya`（neko_chemistry等の既存アプリと同じ書式）
- 「アプリ情報」でカテゴリ（プライマリ）を「エンターテインメント」に設定
- 「価格および配信状況」で価格を無料（$0.00、全175か国・地域）に設定
- iPad（13インチディスプレイ）用スクリーンショット5枚を撮影・アップロード
  （`./tool/screenshots.sh "iPad Pro 13-inch (M5)" screenshots_ipad` で撮影、解像度2064×2752）
  — 複数ファイルを一括アップロードすると非同期処理の完了順で並び替わり順序が崩れるため、
  1枚ずつ順番にアップロードすること
- 「審査用に追加」→ 提出物の下書きから「審査へ提出」で最終提出完了

審査完了までは最大48時間程度（App Store Connectの表示による）。完了するとメールで通知が届く。

### Android（Google Play Console）

Google Play Console でアプリ「ネタメーカー」を作成済み（パッケージ名 `jp.pairof.netamaker`、
App ID `4975121456073481916`）。以下を入力・保存済み:

- ストアの掲載情報（アプリ名・簡単な説明・詳しい説明・アプリのアイコン・フィーチャーグラフィック・
  携帯電話版スクリーンショット5枚）
- コンテンツのレーティング（IARCアンケート回答済み）
- ターゲットユーザーおよびコンテンツ（対象年齢13歳以上として申告）
- プライバシーポリシーURL（https://nullstead.com/apps/neta-maker/privacy）
- 広告の宣言（広告を表示するアプリとして申告）
- 広告ID宣言（使用する、目的は「広告、マーケティング」）
- データセーフティ（デバイスID・広告データを「サードパーティ広告」目的・ユーザーに紐付けないで申告）
- アプリのカテゴリ（エンタテインメント）
- 連絡先情報

**リリース署名鍵を生成済み（2026-08-03）**: `android/upload-keystore.keystore` +
`android/key.properties`（どちらもgit管理外）。`android/app/build.gradle.kts` に
signingConfigsを追加し、key.propertiesがあれば本番鍵、なければdebug鍵で署名する構成にした。

**AABアップロードもAndroid Publisher API経由で完結できる（2026-08-03確認）:**

1. Google Cloud プロジェクト `neta-maker-play-api` を作成し、Google Play Android Developer APIを有効化
2. サービスアカウント `play-publisher-upload@neta-maker-play-api.iam.gserviceaccount.com` を作成
   （キーは `gcloud iam service-accounts keys create` でローカルに直接出力すること —
   Play Consoleの「キーを追加」ボタン経由のダウンロードはブラウザ自動化環境では常にキャンセルされる）
3. Play Consoleの「ユーザーと権限」→「新しいユーザーを招待」でこのサービスアカウントのメールを招待し、
   対象アプリに「テスト版トラックとしてのアプリのリリース」権限を付与
4. `tool/upload_to_play.py`（要 `.play_upload_venv` に `google-api-python-client`/`google-auth`）で
   `edits.insert` → `edits.bundles.upload` → `edits.tracks.update` → `edits.commit` を実行

```sh
flutter build appbundle --release
source .play_upload_venv/bin/activate  # なければ python3 -m venv .play_upload_venv して pip install
python3 tool/upload_to_play.py jp.pairof.netamaker build/app/outputs/bundle/release/app-release.aab internal
```

2026-08-03にVersion 1.0.0 (versionCode 1) を内部テストトラックにアップロード・公開済み。

**残作業（開発者本人が行う必要がある）:**

- **Google Playの新規デベロッパーアカウント要件**: 本番環境（全ユーザー向け公開）へのアクセスを
  申請するには、クローズドテストを12人以上のテスターで14日間以上実施する必要がある
  （2026-08-03時点でテスターは0人、クローズドテストも未開始）。この条件を満たすまで審査提出はできない。
  内部テストは12人要件の対象外だが、本番アクセス申請には使えない。
- クローズドテストトラックを作成し、テスターを12人以上集めて14日間運用する
- 上記テストが完了したら「公開の概要」ページから「本番環境へのアクセスを申請」→ 審査提出

## 7. 次にやること

- iOS: Xcodeでのビルド作成・アップロードと審査提出（開発者本人の作業）
- Android: リリースビルドの作成・署名、テストトラックへのアップロード、
  クローズドテスト（12人以上×14日間）の実施、その後の本番リリース申請（開発者本人の作業）
