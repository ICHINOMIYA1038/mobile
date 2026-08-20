# iOS App Store 審査提出メモ

TOMOSHIBI小屋の審査却下(2026-07-31 提出分、Submission ID `c976f520-27fe-4053-b88a-ae40cd899fd7`)対応時に確認した内容。他アプリでも同じApple Developerチーム・同じマシンを使う限り流用できる。

## App Store Connect APIキーの置き場所

このマシンには以下のAPIキー(.p8)が既に存在する。**キー本体は秘密情報なのでリポジトリには絶対に含めない。**

| ファイル | 場所 | 備考 |
| --- | --- | --- |
| `AuthKey_3URMU94JK9.p8` | `~/.appstoreconnect/private_keys/` | Xcode/altoolがこのディレクトリを自動的に見に行く標準の置き場所 |
| `AuthKey_B9H23HBRM7.p8` | `~/.appstoreconnect/private_keys/` と `~/.secrets/tomoshibi/` の両方に存在 | |
| `AuthKey_QPR5F336K4.p8` | `~/.secrets/tomoshibi/`(base64エンコード版 `.p8.base64.txt` も同居、CI用シークレット投入向けと思われる) | |
| `SubscriptionKey_NV27Q8657Q.p8` | `~/.secrets/tomoshibi/` | ファイル名から見て「App Store Server API / Subscription Key」(サブスクリプション状態通知・レシート検証用)の可能性が高い。ビルドアップロード用の`AuthKey_*`とは別用途と思われるので、使う前に用途を要確認 |

各キーの **Key ID と Issuer ID の対応関係、権限(Admin/App Manager等)** はこの調査時点では未確認だったが、2026-08-18に`AuthKey_3URMU94JK9.p8`(Key ID `3URMU94JK9`)で以下のIssuer IDを使い、tomoshibiのビルドアップロードが実際に成功することを確認済み(apps/neta_makerの提出メモに記載されていたのと同じキー・Issuer ID)。

- Key ID: `3URMU94JK9`
- Issuer ID: `1039c5ec-53b4-4125-b857-d5059f3f3e74`

## 前提環境(2026-08-04 時点で確認済み)

- Xcode 26.6 (`xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`)
- Team ID: `SZFUZ58P49`
- コード署名: `security find-identity -v -p codesigning` で見つかるのは `Apple Development: RYOHEI ICHINOMIYA (96CM58C79P)` のみ。Distribution証明書はキーチェーンから直接は見えないが、自動署名(`signingStyle: automatic`)で過去にアーカイブ・エクスポートが成功しているため、Xcodeの自動証明書管理で問題なく動くと思われる。

## 新規ビルドの提出手順

1. コード側の修正を完了させ、`pubspec.yaml` (またはXcodeプロジェクト)のビルド番号を上げる(前回は `1.0 (3)`、却下対応版は `(4)` 以降にする)。
2. アーカイブ・IPAエクスポート。`apps/tomoshibi/build/ios/ipa/ExportOptions.plist` に前回分の設定が残っている(`method: app-store-connect`, `signingStyle: automatic`, `teamID: SZFUZ58P49`)ので、これを流用できる。
   ```sh
   cd apps/tomoshibi
   flutter build ipa --export-options-plist=build/ios/ipa/ExportOptions.plist
   ```
   もしくは Xcode の Organizer から手動でアーカイブ→配布。
3. できあがった `.ipa` をApp Store ConnectへアップロードするAPIキーの使用例(2026-08-18にtomoshibiで実際に成功した組み合わせ):
   ```sh
   xcrun altool --upload-app \
     -f build/ios/ipa/tomoshibi.ipa \
     -t ios \
     --apiKey 3URMU94JK9 \
     --apiIssuer 1039c5ec-53b4-4125-b857-d5059f3f3e74
   ```
   (Xcode Organizerや Transporter.app からのアップロードでも可。`~/.appstoreconnect/private_keys/` にキーがあれば、Xcode/Transporterはこれを自動で拾う。)

   `UPLOAD SUCCEEDED` の後に `MinimumOSVersion too low` の警告 (code 90068) が出ることがあるが、これはエラーではなくアップロード自体は成功している。2027年春以降、iOSアプリの最小対応OSバージョンを15.0以上にする必要があるという将来の要件についての事前警告。
4. App Store Connect側(ブラウザ操作、または将来的にはAPI経由)で:
   - 「配信」→ 該当バージョンにアップロードしたビルドを紐付け
   - 「アプリ内購入」/「サブスクリプション」で該当商品を開き、審査用スクリーンショット・審査メモ・配信可否(国/地域)を設定して「審査用に追加」
     - 参考: TOMOSHIBI Pro 月額 (`com.gikyokutosyokan.tomoshibi.pro.monthly`) は2026-08-04にこの手順で「審査用に追加」まで完了済み。残りは新ビルドの添付のみでブロックされていた。
   - バージョン側で「審査へ提出」

## 補足: RevenueCat側の "Could not check" 表示について

RevenueCatの商品詳細ページ(Products > 該当商品)で `Store Status: Could not check` と出ることがあるが、これはRevenueCat自体のApp Store Connect API連携(RevenueCatダッシュボード内の別設定)が未設定なだけで、実際の審査提出状況とは無関係。気になる場合はRevenueCatの Project Settings → Integrations → App Store Connect で上記いずれかのAPIキーを登録する。
