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
| Bundle ID / applicationId | 済 | `com.gikyokutosyokan.etude`（iOS/Androidで統一済み） |
| アプリアイコン | 済 | `icon/icon.svg`・`icon/icon_foreground.svg` が元データ。変更後は `dart run flutter_launcher_icons` で再生成 |
| pubspec の説明文・バージョン | 済 | `description` を実際の内容に更新済み（`version: 1.0.0+1` のまま初回提出） |
| 広告SDK（Google AdMob） | 済 | `google_mobile_ads` を組み込み済み。AdMobで「エチュードメーカー」(iOS/Android)を登録し、実アプリID・実広告ユニットIDに差し替え済み（2026-07-25）。新規広告ユニットは配信開始まで1時間程度かかる場合がある。`google_mobile_ads` は5.3.1→9.0.0へ更新済み（2026-07-27、`getAnchoredAdaptiveBannerAdSize`→`getLargeAnchoredAdaptiveBannerAdSizeWithOrientation`に追従）。iOS/Androidとも再ビルド・実演画面/振り返り画面でのバナー広告読み込み成功を確認済み |
| 課金/アナリティクスSDK | 該当なし | アプリ内課金・分析SDKは組み込んでいない |
| プライバシーマニフェスト（iOS） | 済 | `ios/Runner/PrivacyInfo.xcprivacy`（Xcode登録済み）。トラッキングなし、収集データなし、UserDefaults使用理由(CA92.1)のみ申告 |
| プライバシーポリシーの公開URL | 済 | https://nullstead.com/apps/etude/privacy （2026-07-25公開）。実体は `~/nullstead/web` の別リポジトリ |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com（privacy-policy.md に記載） |
| ストア掲載文（説明・キーワード・カテゴリ） | 済 | `docs/store-listing.md` |
| Androidのリリース署名鍵 | 済 | `~/etude-upload-key.jks` を生成し `android/key.properties`（gitignore済み）に設定（2026-07-25）。`flutter build apk --release` → `apksigner verify --print-certs` で新しい鍵の証明書指紋（SHA-256: `92a0db2f...`）が使われていることを確認済み。**鍵とパスワードは開発者自身で必ずバックアップを取ること**（紛失すると以後アプリを更新できなくなる） |
| **Xcodeで Team を確認** | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49` 設定済み。実機ビルド・アーカイブ前に一度Xcodeで開いて証明書エラーがないか確認すること |
| ストア用スクリーンショット | 済 | `./tool/screenshots.sh` で自動生成（iPhone 6.9インチ 1320×2868、iPad 13インチ 2064×2752 で確認済み）。Google PlayのスマホスクリーンショットもiPhone版をそのまま流用（16:9/9:16以外でも受理された）。下記「4. スクリーンショット」参照 |
| 起動画面（Launch Image / launch_background） | 済 | Flutterテンプレートの1x1透明画像プレースホルダーのままだった箇所を、`icon/icon.png` から書き出した画像に差し替え済み（2026-07-25）。iOS: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`、Android: `android/app/src/main/res/mipmap-*/launch_image.png` + 両`launch_background.xml`。アイコンを変更したら再生成すること |
| **App Store Connect / Google Play Console 上の情報入力** | **済（審査提出済み）** | 詳細は下記「6. 提出状況」を参照 |
| **有料アプリ契約・納税・銀行口座（Apple）** | 該当なし | 無料アプリ・IAPなしのため不要 |

## 2. AdMobの本番設定（完了済み）

takken_simple と同じAdMobアカウントに「エチュードメーカー」を登録済み（2026-07-25）。

| | iOS | Android |
| --- | --- | --- |
| アプリID | `ca-app-pub-8691137965825158~5814806711` | `ca-app-pub-8691137965825158~6967006205` |
| バナー広告ユニットID（実演・振り返り画面バナー） | `ca-app-pub-8691137965825158/2006323561` | `ca-app-pub-8691137965825158/2956709081` |

`ios/Runner/Info.plist`・`android/app/src/main/AndroidManifest.xml`・`lib/data/ad_service.dart`
の3箇所に反映済み。新規に作成した広告ユニットは、配信が始まるまで1時間ほどかかる場合がある
（すぐに広告が表示されなくてもテストIDへの巻き戻し等は不要）。

広告は**常に非パーソナライズ広告**として配信する設定にしているため、ATT（トラッキング許可）ダイアログは表示されない。
パートナーでの入札（サードパーティのメディエーション/RTB）は使っていない。AdMob単独運用。

## 3. コンソール入力の下書き

### アプリ情報

- **名前**: エチュードメーカー
- **サブタイトル**: 人数とジャンルを選ぶだけで即興のお題が一瞬で
- **カテゴリ**: エンターテインメント（第2候補: 教育）
- **年齢制限**: 4+ / 全年齢

### App のプライバシー（申告内容）

本アプリはアカウント登録・分析SDKを持たないが、**Google AdMobを組み込んでいるため、SDKが扱う分を申告する必要がある**。

- トラッキング: **なし**（非パーソナライズ広告のみを配信し、ATT も要求していない）
- 収集するデータ:
  - **識別子 → デバイスID**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
  - **使用状況データ → 広告データ**: 「サードパーティ広告」目的、**ユーザーに紐付けない**
- 「お気に入り」機能で保存する内容（生成したお題の文字列）は端末内の `shared_preferences` にのみ保存され、
  外部送信されないため申告対象外。

App Store Connect の「App のプライバシー」、Google Play の「データセーフティ」とも上記の内容で申告する。

> AdMobの設定を非パーソナライズから変更した場合、この申告と `docs/privacy-policy.md` の
> 2箇所を必ず揃えること。ずれていると審査で落ちる。

### 審査メモ（App Review Information の Notes 欄にそのまま貼る）

```
本アプリは即興演劇（エチュード）の練習用にお題を生成するアプリです。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【通信・データ収集について】
分析SDKは組み込んでいません。Google AdMobによる広告表示のときのみ通信が発生します。
「お気に入り」に保存したお題は端末内にのみ保存され、外部へ送信されません。

【広告について】
実演画面（タイマー表示中）と振り返り画面にのみ、Google AdMobのバナー広告を表示します。
常に非パーソナライズ広告として配信するため、ATT（トラッキング許可）のダイアログは表示していません。

【アプリ内課金】
ありません。すべての機能を無料・無制限でご利用いただけます。

【動作確認の手順】
1. 起動 →「はじめる」→ 設定画面で人数(2〜4人)・ジャンル・時間を選択 →「お題をつくる」
2. 場所・状況・関係・秘密・制約が表示された結果画面が出ます
   （右上のハートアイコンで「お気に入り」に保存できます）
3. 「このエチュードを実行する」→ 一人目から順に「役を引く」を押すと、
   その人だけに見せる役の内容（目的・秘密）が表示されます（この画面に広告は出ません）
4. 全員分を引き終えると「配役完了」→「エチュードを始める」でタイマーが始まります
   （タイマー画面の下部にバナー広告が表示されます）
5. 「終了する」を押すと、演じた後の振り返り用の問いが3つ表示されます（ここにも広告が出ます）
   （「同じお題でもう一度」または「新しいお題を作る」で最初に戻れます）
6. ホーム右上のハートアイコンから「お気に入り」一覧を確認できます
```

## 4. スクリーンショット

**自動生成できる。手で撮らないこと。**

```sh
./tool/screenshots.sh                      # iPhone 16 Pro Max = 6.9インチ（1320×2868）
./tool/screenshots.sh "iPhone 11 Pro Max"  # 6.5インチ（1242×2688）が要る場合
```

`screenshots/` に6枚書き出される。撮る内容は `integration_test/screenshots_test.dart`。

1. `01_home` — タイトル画面（キャッチコピー）
2. `02_settings` — 生成画面（人数・ジャンル・時間の選択UI、3人・ミステリー・10分を選択済み）
3. `03_result` — お題の結果画面（場所・状況・秘密・制約が出そろった状態）
4. `04_role_draw` — 役を引く画面（自分だけに見せる役の内容）
5. `05_performance` — 実演画面（タイマーと全員に見せてよい条件）
6. `06_reflection` — 振り返り画面（演じた後の問い）

生成物なので `.gitignore` 済み。UI を変えたら撮り直すこと。

takken_simple と同じ「シミュレータのtmpディレクトリにマーカーファイルを置き、
`tool/screenshots.sh` の常駐プロセスが `xcrun simctl io screenshot` で撮る」方式。
`IntegrationTestWidgetsFlutterBinding.takeScreenshot()` は iOS + Impeller で単色背景しか
返さない不具合があるため使っていない。

撮影前にシミュレータのステータスバーに他アプリの再生中表示（例: Chromeで再生中の
動画/音楽のNow Playing表示）が映り込むことがある。気になる場合はホスト側の再生を
止めるか、`xcrun simctl erase <UDID>` でシミュレータを初期化してから撮り直すこと。

## 5. バージョン管理

`pubspec.yaml` の `version: 1.0.0+1` が iOS の `CFBundleShortVersionString` /
`CFBundleVersion`、Android の `versionName` / `versionCode` に反映される。
再提出のたびにビルド番号（`+1` の部分）を上げること。

## 6. 提出状況（2026-07-25時点）

### iOS（App Store Connect）

`v1.0.0 (1)` を審査に提出済み。年齢制限4+、Appのプライバシー申告、価格（無料・フランス除く174地域）、
コンテンツ配信権（サードパーティコンテンツなし）、輸出コンプライアンス（標準暗号化のみ・フランス配信なしで
追加書類不要）まで設定済み。結果通知（承認/リジェクト）待ち。

### Android（Google Play Console）

初回アプリ登録、コンテンツ申告（年齢・データセーフティ・広告・行政アプリ・金融取引機能・健康・広告ID）、
ストア掲載情報、クローズドテストのトラック設定まで完了し、審査に提出済み。

**重要**: Google Playの新規アプリは審査が通ってもすぐ本番公開できない。クローズドテストで
**12人以上のテスターに14日間以上参加してもらう**ことが「本番環境へのアクセス」申請の条件。
テスターは開発者側で集める。参加用リンク（オプトインURL）は
Play Console → テストとリリース → クローズドテスト → リリース公開後に「テストへの参加方法」欄に表示される。

14日間・12人以上の条件を満たしたら、ダッシュボードの「製品版へのアクセスの申請」から本番申請を行うこと。
