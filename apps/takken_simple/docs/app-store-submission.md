# App Store 提出メモ

このアプリを審査に出すときの手順と、審査員に伝える内容をまとめたもの。
提出のたびにこの文書を上から順に確認すること。

## 0. 提出前チェック（必ず実行）

```sh
flutter test                                  # 全機能のテスト
flutter test --run-skipped --tags release     # 提出前チェック（未対応があれば赤く出る）
```

`--tags release` が緑になるまで提出しないこと。落ちている項目がそのまま「やり残し」。

## 1. 提出前にやること

| 項目 | 状態 | 場所 |
| --- | --- | --- |
| Bundle ID を `jp.pairof.takken` に統一 | 済 | iOS / Android / macOS |
| アプリアイコン | 済 | `icon/icon.svg` が元データ。変更後は `dart run flutter_launcher_icons` |
| プライバシーマニフェスト | 済 | `ios/Runner/PrivacyInfo.xcprivacy`（Xcode 登録済み） |
| 輸出コンプライアンス申告 | 済 | `ITSAppUsesNonExemptEncryption = false` |
| AdMob の実アプリID | 済 | iOS/Android とも設定済み（下記アカウント欄） |
| AdMob の実バナーID | 済 | 結果画面バナー（iOS/Android） |
| プライバシーポリシーの公開URL | 済 | `privacyPolicyUrl` → https://nullstead.com/apps/takken/privacy （本番公開・200確認済み） |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com |
| IAP 商品の登録 | 済 | App Store Connect で `jp.pairof.takken.remove_ads` を非消費型として登録済み（$2.99・全地域配信・日本語ローカライズ済み）。審査用スクリーンショットのみ未添付 |
| App Privacy 申告 | 済 | デバイスID・広告データとも「サードパーティ広告」目的、トラッキング不使用で保存済み |
| App Review 連絡先・審査メモ | 済 | 姓名・メールと審査メモを保存済み。**電話番号のみ未入力**（ご自身で入力） |
| サブタイトル | 済 | 「配点順に出る宅建の一問一答」 |
| **プロダクト画面のスクリーンショット** | **未** | 見出し入りの完成版を `store_screenshots/`（iPhone）と `store_screenshots_ipad/`（iPad）に生成済み。App Store Connect のメディアマネージャーへ順番どおり手動アップロードすること |
| **Xcode で Team を設定** | **未** | `ios/Runner.xcworkspace` → Signing & Capabilities（証明書が自動生成される） |
| 有料アプリ契約・納税フォーム・銀行口座 | 済 | App Store Connect「ビジネス」ページで確認済み（有料アプリ契約：有効、銀行口座：Sumitomo Mitsui Banking Corporation 有効、納税フォーム：U.S. Certificate of Foreign Status of Beneficial Owner / U.S. Form W-8BEN とも2026年7月24日提出・有効） |

### 2026-07-21 Guideline 2.1(a) 差し戻し対応

審査端末で「広告を削除する」を押した際、StoreKit から商品が返らず
「この端末では購入できません」と表示された。コード上の商品IDとBundle IDは一致している。
再提出前に App Store Connect で次をすべて確認すること。

1. 「広告を削除」(`jp.pairof.takken.remove_ads`) に審査用スクリーンショットを添付する。
2. IAP のステータスを「審査待ち」にし、App Version 1.0 の「アプリ内課金とサブスクリプション」へ追加する。
3. 有料アプリ契約が有効になっていることを「ビジネス」で確認する。
4. Sandbox / TestFlight の新規インストールで、価格表示と購入シートの表示をiPhone・iPadの両方で確認する。
5. IAP を含めて再提出し、Resolution Center に下記の返信を送る。

```text
ご連絡ありがとうございます。

原因を確認したところ、非消費型アプリ内課金「広告を削除」の商品情報が審査環境で
取得できない状態でした。App Store Connect の商品メタデータと審査用スクリーンショットを
確認し、当該アプリ内課金を App Version 1.0 と関連付けて審査へ提出しました。

また、StoreKit は利用可能でも商品情報を取得できない場合を端末非対応と表示していたため、
そのエラー表示も修正しました。iPhoneおよびiPadの新規インストール環境で、価格の表示、
購入シートの表示、購入の復元を確認済みです。

お手数をおかけしますが、再度ご確認をお願いいたします。
```

## 2. App Store Connect の入力内容

### AdMob アカウント（作成済み）

| | iOS | Android |
| --- | --- | --- |
| アプリID | `ca-app-pub-8691137965825158~1913298149` | `ca-app-pub-8691137965825158~6905082015` |
| バナー広告ユニットID（結果画面バナー） | `ca-app-pub-8691137965825158/6343377604` | `ca-app-pub-8691137965825158/2819065567` |

パートナーでの入札（サードパーティのメディエーション/RTB）は使っていない。
AdMob 単独運用で、非パーソナライズ広告のみ配信する方針と揃えている。

### アプリ情報

- **名前**: シンプルに学ぶ宅建
- **サブタイトル**: 配点順に出る宅建の一問一答
- **カテゴリ**: 教育（第2カテゴリ: 参考書）
- **年齢制限**: 4+

### App のプライバシー（申告内容）

本アプリ自身は一切のデータを収集しない。ただし **AdMob を組み込んでいるため、SDK が扱う分を申告する必要がある**。

- トラッキング: **なし**（非パーソナライズ広告のみ配信し、ATT も要求していない）
- 収集するデータ:
  - **識別子 → デバイスID**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
  - **使用状況データ → 広告データ**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
- 学習履歴は端末内のみで外部送信がないため、申告対象外。

> AdMob の設定を非パーソナライズから変更した場合、この申告と `PrivacyInfo.xcprivacy`、
> `docs/privacy-policy.md` の3か所を必ず揃えること。ずれていると審査で落ちる。

### 審査メモ（App Review Information の Notes 欄にそのまま貼る）

```
本アプリは宅地建物取引士試験のための○×形式の学習アプリです。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【他アプリとの違い（重要）】
宅建の本試験は全50問で、内訳は宅建業法20問・権利関係14問・法令上の制限8問・
税その他8問と、科目ごとに配点が異なります。つまり宅建業法1問は税その他1問の
2.5倍の価値がありますが、既存の学習アプリはどの科目も均等に出題しています。

本アプリは出題頻度をこの配点比率に直接連動させ、合格に効く科目から自動的に
多く出題します（成績画面のバーの長さも配点比率に対応しています）。
また、得点表示を「正答率○%」ではなく「本試験の配点で換算した予想得点（50点満点）」
で示し、合格ラインまであと何点かが分かるようにしています。

さらに、忘却曲線に基づく間隔反復（SM-2 を○×2択用に簡略化したもの）を実装し、
間違えた問題ほど頻繁に、定着した問題ほど間隔を空けて自動的に再出題します。
類似アプリはこうした出題方式をユーザーにモード選択させますが、本アプリは
学習者が設定を一切せずに済むことを設計上の中心に据えています。

収録問題数は300問で、全問に解説と根拠条文を付しています。

【アプリ内課金】
「広告を削除」（非消費型・買い切り）のみです。
広告はもともと結果画面にのみ表示し、出題中・解説中には表示しません。
購入しなくても300問すべてを制限なく利用できます。
成績画面に「購入を復元する」を用意しています。

【広告について】
Google AdMob を使用していますが、常に非パーソナライズ広告として配信するため、
ATT（トラッキング許可）のダイアログは表示していません。

【通知について】
すべて端末内で完結するローカル通知です。サーバーからのプッシュ通知は使用しておらず、
デバイストークンの送信も行いません。復習すべき問題がたまった日にのみ、
1日1回（20時）お知らせします。許可は初回の学習を終えた直後にお伺いします。

【動作確認の手順】
1. 起動 →「5問はじめる」（復習がある場合は「今日の復習」）→ ○か×をタップ → 解説が表示されます
2. 「次の問題へ」で出題が続き、5問目の「結果を見る」で結果画面へ進みます
3. 結果画面にのみ広告が表示されます（途中終了は左上の×）
4. ホーム右上のグラフアイコン → 成績画面
   （予想得点・合格グラフ・広告削除の購入と復元・プライバシーポリシー）
5. 初回の学習を終えると、復習のお知らせの許可をお伺いします
```

## 3. Guideline 4.2 (Minimum Functionality) で差し戻された場合

クイズ系アプリで最も起きやすい差し戻し。実際に落ちた場合の対応方針:

1. **Bundle ID は絶対に変えない**（変えると審査履歴が切れて不利になる）
2. 上記「他アプリとの違い」を Resolution Center で改めて説明する。
   機能を足すより、**既存アプリが均等出題しかしていない中で本アプリだけが配点連動である**
   という一点を具体的な数字（20:14:8:8）で示すのが有効。
3. それでも通らない場合、実機の操作を録画した動画を添える。
   出題が宅建業法に偏ることと、間違えた問題が再出題されることを画面で見せる。
4. Apple Developer の Contact Us から電話で補足説明を依頼する手もある。

## 4. スクリーンショット

**自動生成できる。手で撮らないこと。** 2026-08-21〜、見出し合成は
`tool/store_previews.sh`（ImageMagick）から fastlane `frameit`（実機ベゼル付き）に
移行済み。詳しい仕組みは [`docs/screenshot-guidelines.md`](../../../docs/screenshot-guidelines.md)
参照。

```sh
./tool/screenshots.sh                      # iPhone 16 Pro Max = 6.9インチ（1320×2868）
./tool/screenshots.sh "iPhone 11 Pro Max"  # 6.5インチ（1242×2688）が要る場合
./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad  # iPad 13インチ

# 生スクショを fastlane のロケールフォルダへ配置してから frameit を実行
cp screenshots/*.png ios/fastlane/screenshots/ja/
for f in 01_home 02_quiz 03_explanation 04_pass_gauge 05_pass_graph; do
  cp "screenshots_ipad/${f}.png" "ios/fastlane/screenshots/ja/${f}_ipad.png"
done
cd ios && bundle install && bundle exec fastlane ios compose_screenshots
```

`screenshots/` に5枚書き出される。撮る内容は `integration_test/screenshots_test.dart`。

1. `01_home` — ホーム（5問セッションと自動復習）
2. `02_quiz` — 出題画面（○×の2択）
3. `03_explanation` — 解説（根拠条文まで写る）
4. `04_pass_gauge` — 合格ゲージ（合格ラインまであと何点か）
5. `05_pass_graph` — **合格グラフ ← 差別化が一番伝わる画面。ストアの1枚目に置くこと**

まっさらな状態では合格グラフの良さが伝わらないため、スクリプトが学習の進んだ状態を
作ってから撮っている（170/300問・12日連続）。この値を変えたい場合は
`screenshots_test.dart` の `plan` を編集する。

見出し・サブ見出しの文言や背景色は `ios/fastlane/screenshots/Framefile.json` を編集する。
完成品は `ios/fastlane/screenshots/ja/*_framed.png`。
`bundle exec fastlane ios upload_metadata` でApp Store Connectへアップロードできるが、
**実際に反映されるため実行前に必ずユーザーへ確認すること**。

生成物（`screenshots/` `screenshots_ipad/` `ios/fastlane/screenshots/ja/*_framed.png`
`ios/fastlane/frame_assets/fonts/`）は `.gitignore` 済み。UI を変えたら撮り直すこと。

## 5. バージョン管理

`pubspec.yaml` の `version: 1.0.0+3` が iOS の
`CFBundleShortVersionString` と `CFBundleVersion` に反映される。
再提出のたびにビルド番号（`+1` の部分）を上げること。
