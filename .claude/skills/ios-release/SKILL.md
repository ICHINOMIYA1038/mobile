---
name: ios-release
description: このリポジトリの iOS アプリをリリースするときの手順と落とし穴。pubspec のビルド番号（+N）を上げる、flutter build ipa、altool で App Store Connect にアップロード、ビルドの VALID 待ち、審査提出（attach_submit.py / fastlane ios submit_review）、審査状態の確認、却下後の再提出、承認後に App Store に出ているか（配信地域）の確認をするときに使う。
---

# iOS リリース〜審査提出

App Store Connect（ASC）への書き込み（アップロード・バージョン作成・メタデータ・審査提出・キャンセル）は
実際に反映される。ユーザーが頼んだアプリ・バージョンの範囲だけで行う。Android / Google Play は対象外。

鍵: `~/.appstoreconnect/private_keys/` の `.p8`。Key ID / Issuer ID は `scripts/asc/asc.py` の `KEY_ID` / `ISS` を使う
（値をコマンド例・ドキュメント・コミットに書き写さない）。共通手順の原本は `ios-app-review-submission.md`
「App Store Connect API だけで提出する」、アプリ固有の事情は `apps/<app>/docs/app-store-submission.md`。

## 手順

1. **現状確認**（リポジトリのルートで）
   ```sh
   python3 scripts/asc/asc.py   # 全アプリの appId・バージョン状態・reviewSubmission の状態
   ```
   対象アプリに `UNRESOLVED_ISSUES` や `READY_FOR_REVIEW` の提出が残っていないか見る（→ 落とし穴 1）。

2. **ビルド番号を上げる**: `apps/<app>/pubspec.yaml` の `version: X.Y.Z+N`。N は ASC にアップロード済みの
   最大ビルド番号より大きくする。マーケティングバージョンを変えるなら X.Y.Z も。

3. **ASC 側にバージョンを用意**（新しいマーケティングバージョンのとき）: `asc.send()` で
   `POST /v1/appStoreVersions`（platform IOS, versionString, relationships.app）→ `PATCH /v1/appStoreVersionLocalizations/{id}`
   で whatsNew・keywords・description・promotionalText。name / subtitle は `PATCH /v1/appInfoLocalizations/{id}` だが、
   配信中（READY_FOR_DISTRIBUTION）側の appInfo は 409 になるので、新バージョン作成で出来る PREPARE_FOR_SUBMISSION 側に対して行う。
   文言の控えは `apps/<app>/docs/store-listing.md` に残す。fastlane で出すアプリ（sound_shield）は `ios/fastlane/metadata/` を更新する。

4. **ビルド**
   ```sh
   cd apps/<app>
   flutter build ipa --release --export-options-plist=build/ios/ipa/ExportOptions.plist
   ls build/ios/ipa/*.ipa        # ファイル名は CFBundleDisplayName（日本語のことがある）
   ```
   - `ExportOptions.plist` が無ければ他アプリの `build/ios/ipa/ExportOptions.plist` をコピー（Team・署名設定は共通）
   - `--dart-define` が要るアプリがある（例: doremi_scan は `OMR_API_URL` と `APP_KEY`（`~/.secrets/doremi/` から読む）。
     無いとリリースビルドが例外で止まる）。各アプリの app-store-submission.md / README を見る

5. **アップロード**
   ```sh
   xcrun altool --upload-app -f build/ios/ipa/<名前>.ipa -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
   ```
   `KEY_ID` / `ISSUER_ID` はシェル変数で渡す（asc.py から取る）。`UPLOAD SUCCEEDED` の後の 90068 `MinimumOSVersion too low` 警告は無害。

6. **VALID 待ち → 審査提出**（どちらか）
   - 標準（全アプリ）: `python3 scripts/asc/attach_submit.py <appId> <appStoreVersionId> <N>`
     — ビルドの processingState が VALID になるまで最大約20分ポーリング → 輸出コンプライアンス false → ビルド添付 →
     reviewSubmission 作成（または既存を再利用）→ item 追加 → submitted=true
   - fastlane の `submit_review` レーンがあるアプリ（今は sound_shield だけ）: VALID を確認してから
     `cd apps/<app>/ios && bundle exec fastlane ios submit_review version:X.Y.Z build:N`
     （deliver でメタデータ+スクショ反映・ビルド紐付け・提出・承認後自動リリースまで一括）。
     VALID 確認は `asc.get('/v1/builds', {'filter[app]': APP_ID, 'filter[version]': 'N'})` の `processingState`

7. **提出確認**: `python3 scripts/asc/asc.py` でバージョンが `WAITING_FOR_REVIEW` になっていること。
   `apps/<app>/docs/app-store-submission.md` に「何を直して何日に提出したか」を追記する。

8. **承認後の確認（毎回）**: `READY_FOR_DISTRIBUTION` になったら、実際にストアに出ているかを
   `python3 scripts/asc/search_rank.py`（先頭で iTunes Lookup）か `https://itunes.apple.com/lookup?id=<appId>&country=jp` で確かめる（→ 落とし穴 2）。

## 落とし穴

1. **却下済みの提出が新規提出をブロックする**: 却下された reviewSubmission は `UNRESOLVED_ISSUES` のまま残り、
   「A review submission is already in progress」で新しい提出が失敗する。`attach_submit.py` はこの状態の提出も
   再利用しようとするので、先にキャンセルする: Spaceship の `ReviewSubmission#cancel_submission`、または
   `asc.send('PATCH', '/v1/reviewSubmissions/<id>', {'data': {'type': 'reviewSubmissions', 'id': '<id>', 'attributes': {'canceled': True}}})`。
   却下理由は API では読めない。ASC Web の Resolution Center で読む。
2. **承認されたのにストアに無い（「App Store から削除済み」に見える）**: 配信地域（app availability）が未設定。
   `GET /v1/apps/{id}/appAvailabilityV2` が 404 なら、`POST /v2/appAvailabilities` で全 175 地域を available にする。
   included の territory エンティティの local id は base64 ではなく `${JPN}` のようなリテラル形式。反映まで数時間かかる
   （`PROCESSING_TO_AVAILABLE`）。ネタガチャ・Sound Shield で発生。新規アプリは初回提出前に設定しておく。
3. **Crashlytics のスクリプトで ARCHIVE FAILED**（`Could not find the Crashlytics upload symbols script`）:
   `flutter build ipa` は Swift パッケージを `<app>/build/ios/SourcePackages/` に置くが、flutterfire の Run Script は
   DerivedData しか見ない。`apps/takken_simple` / `apps/sound_shield` の `project.pbxproj` にある
   `$SRCROOT/../build/ios/SourcePackages` を先に探す分岐をコピーする。
4. **配布証明書が無い**（`No signing certificate "iOS Distribution" found`）: docs/maintenance.md「8. 配布用の署名」の手順で作り直す。
   login キーチェーンに入れると codesign が GUI の許可待ちで無言で固まるので専用キーチェーンにする。
   この API キー（App Manager 権限）では `-exportArchive` のクラウド署名が通らないため手動署名。
5. **新規アプリ・初回課金のとき**
   - アプリの価格（無料）が未設定だと `STATE_ERROR.APP_PRICING_REQUIRED` で提出全体が止まる
   - 初めての IAP / サブスクは API から提出に入れられない（`FIRST_*_MUST_BE_SUBMITTED_ON_VERSION`）。
     ASC Web で各商品の「審査用に追加」（サブスクはグループと商品の両方）を、同じ下書き提出にバージョンが入った状態で行う。
     IAP・価格の作成 API はこのキーでは 403。審査用スクリーンショットの差し替えは API でできる
   - 年齢制限を API でコピーするときは `ageRatingOverride` を落とす（`ageRatingOverrideV2` と衝突して 409）
   - RevenueCat の公開 SDK キーは提出前に検証する:
     `curl -H "Authorization: Bearer <key>" -H "X-Platform: ios" https://api.revenuecat.com/v1/subscribers/x/offerings`（401 = 誤り）
6. **スクショ起因の却下**: 「無料」等の文言はガイドライン 2.3.7 の価格表記扱い。iPad 対応（`TARGETED_DEVICE_FAMILY` に 2）の
   アプリは iPad スクショが必須。
7. **ASC Web をブラウザで操作するとき**: フォームは React なので、実際のタイピングか native setter + input/change イベントで値を入れ、
   ダイアログ自身の「保存」を押す。プログラムからの `.click()` だけでは選択が反映されないことがある。
