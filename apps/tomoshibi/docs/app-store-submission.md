# App Store 提出メモ（TOMOSHIBI小屋）

提出のたびにこの文書を上から順に確認すること。署名・アップロードの手順そのものは
リポジトリルートの `ios-app-review-submission.md` にまとめてある（全アプリ共通）。

直近の却下と対応は [4.3a-rejection-response.md](4.3a-rejection-response.md) を参照。

## 0. 提出前チェック（必ず実行）

```sh
cd apps/tomoshibi
flutter analyze
flutter test
```

両方エラーなしになるまで提出しないこと。

## 1. 提出前にやること

| 項目 | 状態 | 場所・備考 |
| --- | --- | --- |
| Bundle ID | 済 | `com.gikyokutosyokan.tomoshibi` |
| アプリアイコン | 済 | `assets/icon/app_icon.png`（`dart run flutter_launcher_icons`で反映） |
| pubspec の説明文 | 済 | 2026-08-28に雛形の`"A new Flutter project."`から実内容へ修正 |
| バージョン／ビルド番号 | **要更新** | 現在`1.0.0+6`。提出のたびに必ず上げる |
| 課金SDK | 済 | RevenueCat (`purchases_flutter`)。商品 `com.gikyokutosyokan.tomoshibi.pro.monthly` は2026-08-04に「審査用に追加」済み |
| ATT | 済 | `NSUserTrackingUsageDescription` 設定済み。許諾結果は`X-ATT-Status`ヘッダでサイト側へ渡す |
| プライバシーポリシーの公開URL | 要確認 | サイト側フッターの「プライバシー」。ASCの申告と一致しているか確認 |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com |
| コンテンツ配信権 | 要注意 | WebViewで自社サイトを表示するため、「サードパーティのコンテンツを表示する」に該当しない旨を正しく申告すること |
| ストア用スクリーンショット | 済（**ASCへの反映は未**） | 2026-08-28にWeb側修正の反映後、5枚を撮影し`frameit`で合成済み。実体は`ios/fastlane/screenshots/ja/*_framed.png` |
| 袖(sidewing)視点の不具合 | 済 | Web側 `src/App.tsx` の `CAMERA_VIEWS` を修正し、2026-08-28に本番反映済み（PR #1）。下記「3. スクリーンショット」参照 |
| App Review Information の Notes | 済 | 2026-08-28にASC APIで更新済み。**上限4000文字**で、更新前は3997文字とほぼ限界だったため、解決済みの過去指摘を1行に圧縮して4.3(a)の説明を先頭に据えた。全文は下記「2. 審査メモ」 |
| Team | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49`、`CODE_SIGN_STYLE = Automatic` |
| 端末上のアプリ名 | 要検討 | `CFBundleDisplayName = "Tomoshibi"` に対しストア名は「TOMOSHIBI小屋」。Guideline 2.3.8的には関連していれば可だが、揃えるなら文字数（ホーム画面で切れる）とセットで判断する |

## 2. 審査メモ（App Review Information の Notes）

2026-08-28にASC APIで下記を設定済み（3,268文字 / 上限4,000文字）。
**この欄は空ではなく、過去の却下対応の履歴が積み上がっていた。**上限に達していたため、
解決済みの指摘（2.1(b) / 3.1.2(c) / 3.1.1 / 2.1 / 5.1.1(v) / 2.1(a)）は末尾1行に圧縮し、
いま争点になっている4.3(a)の説明を先頭へ移した。英語で書いているのは、審査担当が
日本のチームとは限らないため。更新前の内容は必要なら履歴から復元すること。

```
TOMOSHIBI小屋 is a 3D stage-lighting planning tool for theatre practitioners. It is the first-party iOS client of our own web service at https://tomoshibi.gikyokutosyokan.com/

[Regarding the Guideline 4.3(a) rejection of the Aug 27, 2026 submission]

This app is not a repackaged template. We designed, built and operate the service ourselves as 戯曲図書館 (Gikyoku Toshokan) - the same entity that owns the domain gikyokutosyokan.com and the bundle ID com.gikyokutosyokan.tomoshibi. All content, 3D assets, fixture photometric data and application logic are our own original work. We did not purchase, license or adapt any app template, and no part of the codebase came from a third-party template vendor.

What the app does, which we believe no other App Store app offers: the user rigs lighting instruments on battens, places performers on a 3D stage, and inspects how the light actually falls from the four viewpoints used in real theatre production work - 客席 (from the audience), 俯瞰 (overhead plan), 袖 (from the wings) and 自由 (free camera) - and toggles 客電 (house lights) to compare working light against performance light. Rendering is physically based: inverse-square falloff, soft shadows, and Henyey-Greenstein volumetric scattering so beams are visible in haze. The fixture library carries per-model beam angle, luminous flux and colour temperature for 22 conventional and LED instruments (PAR64, Fresnel, PC, Source Four, and LED models from Stairville, Chauvet, ADJ, ETC and Robe).

How to verify in under a minute (no sign-in needed):
1. Launch the app. A 3D stage is shown.
2. Tap 客席 / 俯瞰 / 袖 / 自由 at the top left to switch viewpoint.
3. Tap 客電 to toggle the house lights on and off.
4. Open the round menu button at the bottom right to add instruments and performers.

We have also replaced every App Store screenshot for this submission so that the listing shows this functionality directly.

Architecture: the app renders our own web application inside a WKWebView, together with native iOS integrations written specifically for this app - ATT gating of our analytics, sign-in via ASWebAuthenticationSession with a one-time-token handoff into the app's own cookie store, Universal Links routing, and StoreKit purchase and restore. The web application it loads is entirely our own product, not third-party or syndicated content.

If the similarity finding stands, could you please tell us which specific app(s) TOMOSHIBI小屋 was matched against, or which element of the binary or metadata triggered it? We will address it directly in the next build.

Accounts and purchases: signing in is optional and is never required to use the app or to buy. "TOMOSHIBI Pro 月額" (com.gikyokutosyokan.tomoshibi.pro.monthly, JPY 300/month) is sold through StoreKit; the Stripe checkout used on the web is intercepted in-app and replaced with the native IAP. Restore is always available from the button at the bottom left, whether signed in or not. Terms of Use: https://tomoshibi.gikyokutosyokan.com/terms

Previously reported issues - 2.1(b) IAP not submitted, 3.1.2(c) EULA link, 3.1.1 restore, 2.1 ATT on iPadOS, 5.1.1(v) registration before purchase, and 2.1(a) Sign in with Apple (SameSite cookie on the OAuth callback) - were all fixed in builds 4 to 6 and remain fixed.
```

## 3. スクリーンショット

撮影から合成までスクリプト化してある。UIやシーンを変えたら撮り直すこと。

```sh
./tool/screenshots.sh                                  # iPhone 16 Pro Max (1320x2868)
./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad
cp screenshots/*.png ios/fastlane/screenshots/ja/
cd ios && bundle install && bundle exec fastlane ios compose_screenshots
```

仕組み（このアプリ固有の事情）:

- 画面の中身はWebViewなので、WidgetTesterから器具を並べたり視点を切り替えたりできない。
  代わりにWeb側の共有URL `#scene=<base64>`（`tomoshibi/src/io/sceneIO.ts`）を使い、
  **器具・役者・カメラ視点・客電を全部含んだシーンをURLとして流し込む**。
  1枚のスクリーンショット = 1つのURL。
- URLの元データは `tool/build_scene_urls.py` の `SHOTS` / `FIXTURES` / `PERFORMERS` が
  唯一の出典。ここから `integration_test/scene_urls.g.dart`（撮影用）と
  `ios/fastlane/screenshots/Framefile.json`（見出し）の両方を生成する。
  見出しを変えたいときも**このPythonを編集して再生成する**こと。
- `lib/main.dart` の `TomoshibiApp` は `startUrl` / `requestTracking` を受け取れる。
  撮影時のみ `requestTracking: false` にしてATTのOSダイアログが写り込むのを防いでいる。
  リリースビルドの挙動は変わらない。
- 撮影前にシミュレータを必ずシャットダウンしてから起動する。直前に別アプリを触っていると
  ステータスバーに「◀ Safari」のような戻りリンクが残り、写り込む
  （過去の提出物に「◀ 猫と学ぶ高校化学」が写っていた原因）。
- WebViewの中のWebGLの描画完了はFlutter側から観測できないため、1枚あたり25秒待っている。

### 前提: Web側の変更はデプロイしないとスクショに反映されない

このアプリはWebView経由で本番サイトを読み込むため、**Web側（`~/private/tomoshibi`）を
デプロイしない限り、修正はアプリにもスクリーンショットにも反映されない。**
撮影前に、配信中のバンドルが期待どおりか確かめられる:

```sh
B=$(curl -s https://tomoshibi.gikyokutosyokan.com/ | grep -oE 'assets/index-[^"]+\.js' | head -1)
curl -s "https://tomoshibi.gikyokutosyokan.com/$B" | grep -c '\-6\.8,1\.7,1\.4'   # 袖カメラの修正が入っていれば 1
```

2026-08-28に `src/App.tsx` で以下を直し、**本番反映済み**（PR #1）。

| 直したもの | 内容 |
| --- | --- |
| `CAMERA_VIEWS.sidewing` | `pos = [-9, 3, 4]` はサイドウォール（`x = -8`, `scene/Stage.tsx`）の**外側**で、壁の裏面が画面の大半を黒く覆っていた。下手袖の内側 `[-6.8, 1.7, 1.4]` へ移動 |
| `CAMERA_VIEWS.aerial` | 縦画面で舞台が下に寄り中央が黒く抜けていたため、`[0, 13, 4]` へ寄せて仕込み図に近い俯瞰にした |
| `ResponsiveFov`（新規） | 縦長画面では垂直fov 45°のままだと水平画角が極端に狭くなり、幅12mのプロセニアム開口の中央数メートルしか映らなかった。アスペクト比が1未満のとき、横長時と同じ水平画角を保てるところまでfovを広げる（上限70°）。横長画面の見え方は変わらない |

Web側のUIやカメラを触ったら、デプロイ → 撮り直し → 合成の順でやり直すこと。

### 既知の落とし穴: 連続撮影中のクラッシュ

WebGLコンテキストとボリュメトリックのレンダーターゲットは重く、前のWebViewを破棄せずに
シーンを作り直し続けると、シミュレータのメモリを使い切ってアプリごと落ちる
（2026-08-28に4枚目で発生）。`screenshots_test.dart` は1枚ごとに
`pumpWidget(SizedBox.shrink())` を挟んで明示的に破棄させている。

またアプリが落ちると `flutter test` は死んだ接続を待ったまま固まり、途中までの
スクショだけが残る。`tool/screenshots.sh` は最後に**期待枚数がすべて揃っているか
突き合わせ、欠けていれば異常終了する**ようにしてある。

## 4. アプリの暗号化書類

- 標準的な暗号化アルゴリズムのみ（HTTPS等）を使用
- フランスでの配信予定: いいえ

（他アプリと同じ回答。詳細は `ios-app-review-submission.md` 参照）

## 5. 提出状況

| 日付 | 内容 |
| --- | --- |
| 2026-07-31 | 1.0 提出 → 却下（Guideline 4 / 5.1.1(v) / 5.1.2(i) / 3.1.1）。Submission ID `c976f520-27fe-4053-b88a-ae40cd899fd7` |
| 2026-08-04 | IAP「TOMOSHIBI Pro 月額」を「審査用に追加」まで完了 |
| 2026-08-18 | ビルドアップロード成功を確認（APIキー `3URMU94JK9`） |
| 2026-08-27 | 1.0 再提出 → **却下（Guideline 4.3(a) スパム）**。Submission ID `63369395-138f-4633-a4b2-bf511b86def9` |
| 2026-08-28 | 対応方針を [4.3a-rejection-response.md](4.3a-rejection-response.md) にまとめた |
| 2026-08-28 | Web側の袖カメラ・俯瞰・縦画面fovを修正し本番反映（tomoshibi PR #1）。ストア用スクリーンショット5枚を撮影・合成 |
| 2026-08-28 | App Store Connectへ反映: スクリーンショット（iPhone 6.9インチ・iPad 13インチとも1枚→5枚、6.5インチのセットは削除）、説明文の加筆、審査メモの書き直し |
| 2026-08-28 14:54 | Resolution Centerへ4.3(a)への返信を送信。**Appleからの回答待ち** |
