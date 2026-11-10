# App Store 提出メモ（TOMOSHIBI小屋）

提出のたびにこの文書を上から順に確認すること。署名・アップロードの手順そのものは
リポジトリルートの `ios-app-review-submission.md` にまとめてある（全アプリ共通）。

直近の却下と対応は [4.3a-rejection-response.md](4.3a-rejection-response.md) を参照。

## 1.0.3 の準備状況（2026-11-11）

App Store で配信中の版は 1.0.2（ビルド 8）。次回のソースは 1.0.3（ビルド 9）。
署名済み IPA は `build/ios/ipa/exported/*.ipa` に作成し、署名を検証済み。
App Store Connect に 1.0.3 の下書きを作成し、掲載文と審査メモを更新した。
iPhone・iPad 各5枚の実画面を撮影・アップロードした。画像は Apple 側で処理中。
IPA のビルド9は処理済み（VALID）で、下書きに紐付けた。暗号化申告も設定済み。
旧照明プランの読み取り専用試算では、9件・4ユーザー分が4プロジェクトへ移行済みで、
追加対象と不整合はともに0件だった。DBの変更はしていない。
審査提出は未実施。
下の「2. 審査メモ」は過去に提出した文面の記録で、
初期画面と購入復元ボタンの位置が現在の画面と異なる。次回の審査には使わない。

次回の審査メモ案:

```text
TOMOSHIBI小屋 is the first-party iOS client of the stage-planning service developed and operated by 戯曲図書館. It combines scene-by-scene staging and lighting in one 3D workspace.

How to try it without an account:
1. Launch the app. The project list opens.
2. Tap “新しいプロジェクトを作る” to open the editor.
3. Tap the current scene card to open the chapter and scene list. Add another scene with the + button or the scene's ⋯ menu.
4. Use the edit panel to add a performer, lighting fixture, or stage set. The floor plan and 3D view show the same stage.
5. Tap “通しで見る” to play the scenes in order.

Sign-in is optional. New Pro purchases use StoreKit inside the app. “購入を復元” remains available in the bar below the web content, including while signed out. The app uses native iOS integrations for ATT consent, sign-in, Universal Links, and StoreKit purchases and restoration.
```

撮影済みの画面と [掲載文案](store-listing.md) は照合済み。

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
| バージョン／ビルド番号 | ビルド済み | 配信中は `1.0.2+8`。次回ソースと IPA は `1.0.3+9`。提出のたびに必ず上げる |
| 課金SDK | 済 | RevenueCat (`purchases_flutter`)。商品 `com.gikyokutosyokan.tomoshibi.pro.monthly` は2026-08-04に「審査用に追加」済み |
| ATT | 済 | `NSUserTrackingUsageDescription` 設定済み。許諾結果は`X-ATT-Status`ヘッダでサイト側へ渡す |
| プライバシーポリシーの公開URL | 済 | ASC の登録 URL とサイトの `/privacy` が一致し、HTTP 200 を確認 |
| 問い合わせ先 | 済 | support@gikyokutosyokan.com |
| コンテンツ配信権 | 要注意 | WebViewで自社サイトを表示するため、「サードパーティのコンテンツを表示する」に該当しない旨を正しく申告すること |
| ストア用スクリーンショット | アップロード済み・処理中 | プロジェクト一覧・3D・平面図・章とシーン・通し再生を iPhone と iPad で各5枚 |
| 袖(sidewing)視点の不具合 | 済 | Web側 `src/App.tsx` の `CAMERA_VIEWS` を修正し、2026-08-28に本番反映済み（PR #1）。下記「3. スクリーンショット」参照 |
| App Review Information の Notes | 済 | 1.0.3 の下書きに上記の審査メモ案を設定・照合済み |
| Team | 済 | `DEVELOPMENT_TEAM = SZFUZ58P49`、`CODE_SIGN_STYLE = Automatic` |
| 端末上のアプリ名 | 済 | 2026-09-24に `CFBundleDisplayName` を「TOMOSHIBI小屋」に変更しストア名と統一（1.0.1〜）。ホーム画面では英字9文字+漢字2文字で収まる |

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

1.0.3 は実際のスタジオ画面を iPhone と iPad で各5枚撮影した。
画面や掲載文を変えたら撮り直すこと。

```sh
./tool/screenshots.sh "iPhone 16 Pro Max" screenshots_103_iphone
./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_103_ipad
cp screenshots_103_iphone/*.png ios/fastlane/screenshots/ja/
for f in screenshots_103_ipad/*.png; do sips -z 2732 2048 "$f" --out "ios/fastlane/screenshots/ja/$(basename "$f" .png)_ipad.png" >/dev/null; done
cd ios && RBENV_VERSION=3.4.4 rbenv exec fastlane ios compose_screenshots
```

合成画像だけを `ios/fastlane/store_upload/ja/` に置き、
`fastlane ios upload_studio_screenshots` で 1.0.3 の下書きに反映する。
元の画像はアップロード対象に混ぜない。

```sh
mkdir -p ios/fastlane/store_upload/ja
cp ios/fastlane/screenshots/ja/*_framed.png ios/fastlane/store_upload/ja/
cd ios && RBENV_VERSION=3.4.4 rbenv exec fastlane ios upload_studio_screenshots
```

撮影の仕組み:

- 画面の中身はWebViewなので、WidgetTesterから器具を並べたり視点を切り替えたりできない。
  `integration_test/screenshots_test.dart` が `?demo=2` の実画面を操作し、
  プロジェクトの保存、平面図、3D、章とシーン、通し再生、一覧の順で撮影する。
- 見出しは `ios/fastlane/screenshots/Framefile.json` で管理する。
- `lib/main.dart` の `TomoshibiApp` は `startUrl` / `requestTracking` を受け取れる。
  撮影時のみ `requestTracking: false` にしてATTのOSダイアログが写り込むのを防いでいる。
  リリースビルドの挙動は変わらない。
- 撮影前にシミュレータを必ずシャットダウンしてから起動する。直前に別アプリを触っていると
  ステータスバーに「◀ Safari」のような戻りリンクが残り、写り込む
  （過去の提出物に「◀ 猫と学ぶ高校化学」が写っていた原因）。
- WebViewの中のWebGLの描画完了はFlutter側から観測できないため、画面ごとに描画待ちを入れている。

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

`tool/screenshots.sh` は最後に期待する5枚がすべて揃っているか確認する。

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
| 2026-08-28 14:54 | Resolution Centerへ4.3(a)への返信を送信 |
| 2026-09-02 | **1.0 審査通過・App Store公開**（返信とメタデータ差し替えのみで通過。バイナリ側の対策は不要になった） |
| 2026-09-24 | 1.0.1(7) を提出（審査待ち）。コールドスタート時のUniversal Linkがホームに上書きされる不具合、サインイン直後のセッション確認の競合、about:blank等を外部に投げて例外になる問題、端末上の表示名を「TOMOSHIBI小屋」に統一、キーワード整理（下記「6. ASO」）。ASC API でバージョン作成→ビルド添付→輸出コンプライアンス→キーワード/リリースノート→reviewSubmission まで実施 |

## 6. ASO（キーワード・検索順位）

2026-09-24 に iTunes Search API（JP）で公開直後の検索順位を確認した。

| 検索語 | 順位 / 件数 |
| --- | --- |
| 舞台照明 | 1位 / 17件 |
| 照明シミュレーター | 1位 / 4件 |
| 舞台 照明 | 1位 / 14件 |
| ステージ照明 | 3位 / 13件 |
| 照明デザイン | 2位 / 47件 |
| 演劇 照明 | 2位 / 3件 |
| 舞台美術 | 4位 / 9件 |
| 劇団 | 12位 / 25件 |
| 舞台監督 | 5位 / 6件 |
| DMX | 圏外 / 47件 |

競合がほぼ無いニッチなので、主要語ではすでに1位。伸びしろは**流入語の裾野を広げる**こと。
1.0 のキーワード欄は「舞台照明,照明シミュレーター,3D,演劇,舞台美術,DMX,照明デザイン,劇団,
ステージ照明,舞台監督」で、`舞台照明`・`3D` はアプリ名/サブタイトルと重複して枠を浪費していた
（Appleはタイトル・サブタイトルの語をキーワード欄に重ねても加点しない）。1.0.1 では
[store-listing.md](store-listing.md) のキーワード欄に差し替える。

