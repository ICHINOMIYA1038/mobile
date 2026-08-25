# App Store 提出メモ

このアプリを審査に出すときの手順と、審査員に伝える内容をまとめたもの。
提出のたびにこの文書を上から順に確認すること。Android/Google Playは現時点でスコープ外
（2026-08-19時点の方針。着手する場合は`ios-app-review-submission.md`の手順は流用できない
ので別途整理すること）。

## 0. 提出前チェック（必ず実行）

```sh
flutter analyze
flutter test
```

両方エラーなしになるまで提出しないこと。

## 1. 提出前にやること

| 項目 | 状態 | 場所 |
| --- | --- | --- |
| Bundle ID | 済 | `jp.pairof.netagacha` |
| アプリアイコン | 済 | `icon/icon.png` / `icon/icon_foreground.png`。アプリ内の
  `CapsuleMachineIllustration`（ガチャマシンのCustomPainter）を1024×1024でレンダリングして
  生成（2026-08-19、`dart run flutter_launcher_icons`で反映済み） |
| pubspec の説明文・バージョン | 済 | `description`を実際の内容に更新済み。`version: 1.0.0+1` |
| 広告SDK（Google AdMob） | 済 | `google_mobile_ads`組み込み済み。AdMobで「ネタガチャ」(iOS)を
  登録し、実アプリID・実バナー/インタースティシャルIDに差し替え済み（2026-08-19）。
  Androidは未登録（テストIDのまま） |
| ローカル通知（配信前リマインダー） | 済 | `flutter_local_notifications`。サーバープッシュではなく
  端末内完結。iOS側の追加のUsage Description設定は不要（OS標準の許諾ダイアログのみ） |
| 課金SDK | 該当なし | アプリ内課金は組み込んでいない |
| プライバシーマニフェスト（iOS） | 未確認 | `ios/Runner/PrivacyInfo.xcprivacy`の内容が実際の
  データ収集方針（広告SDK経由の識別子のみ、アプリ独自の収集なし）と合っているか確認すること |
| プライバシーポリシーの公開URL | 済（要デプロイ） | https://nullstead.com/apps/neta-gacha/privacy
  のページ自体は作成・ローカルビルド確認済み（2026-08-19）。実体は`~/nullstead/web`の別リポジトリ。
  **`wrangler deploy`でのデプロイはまだ実行していない**（そのリポジトリに本タスクと無関係な
  未コミット変更が既にあったため、デプロイ前にユーザー確認が必要）。デプロイ前提でURLを申告するので、
  審査提出前に必ずデプロイを済ませ、URLが実際に開けることを確認すること |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com（`docs/store-listing.md`に記載） |
| ストア掲載文（説明・キーワード・カテゴリ） | 済 | `docs/store-listing.md` |
| **Xcodeで Team を確認** | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49`（他アプリと同じチーム）、
  `CODE_SIGN_STYLE = Automatic`設定済み |
| ストア用スクリーンショット | 済 | `./tool/screenshots.sh`で撮影、fastlane `frameit`で
  実機ベゼル付きに合成済み（2026-08-21〜、`tool/store_previews.sh`から移行。手順は
  `docs/screenshot-guidelines.md`参照）。UIを変えたら撮り直すこと |
| **App Store Connect 上の情報入力** | 未 | 下記「2. 提出状況」参照。アプリ未登録 |
| **有料アプリ契約・納税・銀行口座（Apple）** | 該当なし | 無料アプリ・IAPなしのため不要 |

## 2. 審査メモ（App Review Information の Notes 欄にそのまま貼る）

```
本アプリは配信者向けに、シチュエーション別の雑談ネタ・お題をガチャ形式で提供する
エンターテインメントアプリです。

【アカウント不要】
ログイン機能はありません。起動してすぐ全機能をお試しいただけます。

【通信・データ収集について】
分析SDKは組み込んでいません。Google AdMobによる広告表示のときのみ通信が発生します。
お気に入り・カスタムお題・NGワード設定・リマインダー時刻は端末内にのみ保存され、
外部へ送信されません。

【広告について】
ルーレット画面の下部にバナー広告、ガチャを一定回数引くごとに全画面のインタースティシャル
広告を、Google AdMobで表示します。常に非パーソナライズ広告として配信するため、
ATT（トラッキング許可）のダイアログは表示していません。

【通知について】
「配信前リマインダー」を有効にすると、設定時刻に端末内のローカル通知でお知らせします。
サーバーからのプッシュ通知ではありません。設定はいつでもオフにできます。

【アプリ内課金】
ありません。すべての機能を無料・無制限でご利用いただけます。

【動作確認の手順】
1. 起動 → ホーム画面でシチュエーション（例: 「オープニング」）を1つ選ぶ
2. ノブ（ガチャを引く）をタップ → お題カードが表示される
3. カード右下の星アイコンでお気に入り登録できます（右上の星アイコンから一覧を確認）
4. 右上の鉛筆アイコンから「カスタムお題」画面へ。右下の+ボタンで自分のお題を追加できます
5. 右上の歯車アイコンから「設定」画面へ。NGワードや配信前リマインダーを設定できます
```

## 3. アプリの暗号化書類

- 標準的な暗号化アルゴリズムのみ（HTTPS等）を使用
- フランスでの配信予定: いいえ
（他アプリと同じ回答。詳細は`ios-app-review-submission.md`参照）

## 4. 提出状況（2026-08-20時点）

- iOS 1.0を審査へ提出済み（App Store Connect上のステータス: 「審査待ち」）
- 提出直前に判明し対応した残課題:
  - コンテンツ配信権（アプリ情報）: 「いいえ、サードパーティのコンテンツは含まれておらず、
    表示もアクセスも行わない」で設定
  - 価格および配信状況: Tier 0（無料）、175か国・地域に設定
  - iPad 13インチディスプレイのスクリーンショット: `./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad`
    で撮影し、`tool/store_previews.sh`に`store_screenshots_ipad/`生成分を追加してASCへ
    アップロード（2064×2752）（※`tool/store_previews.sh`は2026-08-21にfastlane
    `frameit`へ移行済み。上表「ストア用スクリーンショット」の行と
    `docs/screenshot-guidelines.md`参照）
- Gitへのコミットもまだ（`git status`で`??`表示のまま）
