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
| 広告SDK（Google AdMob） | **未（重大）** | `google_mobile_ads` を組み込み済み。iOS/Androidとも`GADApplicationIdentifier`/`APPLICATION_ID`はGoogleの**テスト用ID**のまま。実演画面・振り返り画面にバナー広告を表示する実装は完了しているが、**AdMobコンソールで本アプリを登録し、実際のアプリID・広告ユニットIDへ差し替える作業が必要**（下記「AdMobの本番設定」参照） |
| 課金/アナリティクスSDK | 該当なし | アプリ内課金・分析SDKは組み込んでいない |
| プライバシーマニフェスト（iOS） | 未整備 | `ios/Runner/PrivacyInfo.xcprivacy` が存在しない。AdMob SDKを組み込んだため、Xcode 15以降でアーカイブ時に「必須理由API」警告が出た場合は追加が必要 |
| プライバシーポリシーの公開URL | **未** | 本文は `docs/privacy-policy.md` に作成済み。takken_simple と同様 `~/nullstead/web` 側へ公開し、実URLを本ファイルと `store-listing.md` に反映すること |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com（privacy-policy.md に記載） |
| ストア掲載文（説明・キーワード・カテゴリ） | 済 | `docs/store-listing.md` |
| **Androidのリリース署名鍵** | **未（重大）** | `android/app/build.gradle.kts` の `signingConfig` が `debug` のまま。Google Play への提出には本番鍵が必須。鍵の作成・保管は開発者自身の判断で行うこと（このドキュメントでは自動生成しない） |
| **Xcodeで Team を確認** | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49` 設定済み。実機ビルド・アーカイブ前に一度Xcodeで開いて証明書エラーがないか確認すること |
| **ストア用スクリーンショット** | **未** | 下記「4. スクリーンショット」参照。自動生成の仕組みは未整備 |
| **App Store Connect / Google Play Console 上の情報入力** | **未** | アプリの新規作成、年齢区分、App Privacy 申告（「データを収集しない」を選択）、審査メモの貼り付けなど、コンソール側の操作は本ドキュメントの範囲外（開発者が行うこと） |
| **有料アプリ契約・納税・銀行口座（Apple）** | 該当なし | 無料アプリ・IAPなしのため不要 |

## 2. AdMobの本番設定（提出前に必須）

現状は `lib/data/ad_service.dart` の `_prodBannerIos` / `_prodBannerAndroid` が空文字のため、
Googleの**テスト広告**が表示される（収益は発生しない）。本番提出前に以下を行うこと。

1. AdMobコンソール（takken_simple で使っているアカウントと同じもので可）で、新しい「アプリ」として
   「エチュードメーカー」を追加する（iOS/Android それぞれ）。Bundle ID / applicationId は
   `com.gikyokutosyokan.etude`。
2. 各アプリに「バナー」広告ユニットを1つずつ作成する（実演画面・振り返り画面で共用）。
3. 発行された**アプリID**を以下へ反映する:
   - iOS: `ios/Runner/Info.plist` の `GADApplicationIdentifier`
   - Android: `android/app/src/main/AndroidManifest.xml` の `com.google.android.gms.ads.APPLICATION_ID`
4. 発行された**広告ユニットID**を `lib/data/ad_service.dart` の `_prodBannerIos` / `_prodBannerAndroid` へ設定する。
5. `flutter test` を実行し、`test/no_ads_during_activity_test.dart` の
   「AdMobのテストIDが本番IDの定数に紛れ込んでいない」が通ることを確認する。

広告は**常に非パーソナライズ広告**として配信する設定にしているため、ATT（トラッキング許可）ダイアログは表示されない。

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

未整備。用意する場合の想定構成（4枚程度）:

1. ホーム画面（タイトル・キャッチコピー）
2. 生成画面（人数・ジャンル・時間の選択UI）
3. お題の結果画面（場所・状況・秘密・制約）
4. 役を引く画面 or お気に入り一覧

takken_simple の `tool/screenshots.sh` / `integration_test/screenshots_test.dart` が
自動生成の実装例として参考になる（本アプリ用には未移植）。

## 5. バージョン管理

`pubspec.yaml` の `version: 1.0.0+1` が iOS の `CFBundleShortVersionString` /
`CFBundleVersion`、Android の `versionName` / `versionCode` に反映される。
再提出のたびにビルド番号（`+1` の部分）を上げること。
