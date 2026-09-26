# 定期メンテナンス手順（月1回を目安）

2026-09-24 に全アプリの監査→修正→提出を一巡した。次回以降はこの手順で回す。
所要時間はアプリ1本あたり、監査＋修正＋提出で数時間。

## 1. 現状確認（5分）

```sh
python3 scripts/asc/asc.py          # 各アプリのバージョン状態・審査提出の状態
python3 scripts/asc/search_rank.py  # 主要キーワードの検索順位（KW を編集）
./scripts/check_all.sh              # 全アプリの analyze + test
```

確認すること:

- 前回提出したバージョンが `READY_FOR_DISTRIBUTION` になっているか。`REJECTED` /
  `UNRESOLVED_ISSUES` なら App Store Connect の Resolution Center を読む（API では読めない）
- 公開済みのアプリが **iTunes Lookup で見つかるか**（`search_rank.py` の先頭で確認）。
  見つからなければ配信地域の未設定（`appAvailabilityV2` が 404）を疑う。ネタガチャ（2026-08-27）と
  Sound Shield（2026-09-24）で発生
- 評価・レビューが付いていれば内容を読む（`GET /v1/apps/{id}/customerReviews`）

## 2. 監査（アプリごと）

- 読み取り専用のエージェントに「バグ・欠陥を重大度順に file:line 付きで列挙、テストの穴、ASO の問題」を
  出させる。プロンプトの雛形は 2026-09-24 のセッションで使ったもの（各アプリの
  `docs/app-store-submission.md` の追記に何を直したかがあるので、同じ観点で見る）
- 見る観点: 通知（7日分の個別予約になっていないか）、タイマー（ティック数を数えていないか）、
  `RichText` の textScaler、`flutter_localizations`、縦画面固定、SKAdNetwork の件数、UMP の
  タイムアウト範囲、バナー広告の幅、PopScope、setState after dispose、ストア文言と実装のずれ

## 3. 修正 → 提出

各アプリの `docs/app-store-submission.md` の手順で。共通部分は
[`ios-app-review-submission.md`](../ios-app-review-submission.md)「App Store Connect API だけで提出する」。

- `pubspec.yaml` のバージョンを上げる
- `flutter build ipa` → `xcrun altool --upload-app` → `python3 scripts/asc/attach_submit.py`
- リリースノート・キーワード・プロモーション文は `asc.send()` で（各アプリの `docs/store-listing.md` に控え）

## 4. 季節要因

- **宅建**: 試験は毎年10月第3日曜。9月中に最後の更新を提出し、試験後〜翌春は需要が落ちる。
  試験日が過ぎたらプロモーション文の「2026年10月18日の本試験へ」を翌年向けに書き換える
- **猫化学**: 定期テスト前（6月・11月・2月）と共通テスト前（12〜1月）
- **エチュード / ネタガチャ / ネタメーカー**: 季節性は薄い。新学期（4月・9月）に演劇部・配信の
  流入がやや増える

## 5. Apple からの警告メール

- `ITMS-90068 Deployment target too low`: 2026-09-24 に全アプリを iOS 15.0 に上げた。
  新規アプリは `scripts/create_app.sh` が設定する。古いブランチや `flutter create` 直後は要確認
- `ITMS-91053 Missing API declaration`: `PrivacyInfo.xcprivacy` の不足。今のところ未発生

## 6. 話して受かる宅建（takken_talk）だけの確認

サーバー（`~/private/takken-talk-api`、Cloudflare Workers + D1 + Claude）があるので、アプリ本体に加えて月1回:

- **原価**: 次の1行で日ごとのターン数・推定USD・ユーザー数が出る。
  ```sh
  curl -s -H "Authorization: Bearer $(cat ~/.secrets/takken-talk/admin_token.txt)" \
    "https://takken-talk-api.ichiryo108.workers.dev/admin/stats?days=31" | python3 -m json.tool | head -40
  ```
  見るところ: `est_usd` の合計が月の見込みを超えていないか、`turns` が急に跳ねていないか
  （跳ねていたら1人が延々と回している可能性。`users` と突き合わせる）。
  Anthropic Console の Usage と突き合わせ、月の Spend limit（Console 側で設定）を超えそうなら
  `wrangler.toml` の `GLOBAL_DAILY_TURN_CAP` を下げる（既定 3000/日 ≒ ¥6,000/日）。
- **課金の整合**: RevenueCat の Overview（アクティブサブスク数）と `SELECT COUNT(*) FROM users WHERE plan='pro'` が近いか。
  ずれていれば Webhook の失敗（RevenueCat → Webhooks → 履歴）を見る。
- **モデル**: `MODEL = "claude-sonnet-5"` が非推奨予告されていないか（Anthropic の deprecation 一覧）。
  変えるときは `output_config.effort` / `thinking` の対応も確認（`src/chat.ts` は 400 なら thinking なしで再試行する）。
- **法改正**: 4月・10月施行の宅建関連改正を `content/chapters/*.md` に反映して `npm run build:content` → push。
  問題データ（`content/questions.json`）は takken_simple と共通なので、そちらを直したらコピーし直す。
- **D1 のサイズ**: `messages` は要約で圧縮されるが、`turn_ledger` は増え続ける。年1回、13か月より古い行を削除してよい。
- **死活**: `curl -s https://takken-talk-api.ichiryo108.workers.dev/health` が
  `{"ok":true,...,"live":true}` を返すこと。`live:false` なら ANTHROPIC_API_KEY が外れていて、
  アプリは定型文のモック応答になっている（気づきにくいので必ず見る）。
- **課金の審査用スクリーンショット**: 初回提出時のものは、商品がまだ未完成で価格が取れず
  「価格を読み込めませんでした」が写っている。シミュレータは StoreKit に繋がらないので、
  実機＋Sandbox アカウントで撮り直して差し替えること。

## 7. 広告を出すアプリの SKAdNetwork

AdMob を入れたアプリは `ios/Runner/Info.plist` の `SKAdNetworkItems` に、Google の需要パートナー
50件をすべて入れる。Google 本体の `cstr6suwn9.skadnetwork` だけだと、パートナー経由のインストールが
計測されず eCPM が落ちる。2026-09-26 に「シンプルに学ぶ宅建」だけ1件しか無いのを見つけて揃えた。

```sh
# 広告アプリの件数を並べて見る（全部 50 のはず）
for a in apps/*/; do
  [ "$(grep -cE '^  google_mobile_ads' "$a/pubspec.yaml" 2>/dev/null)" = "1" ] || continue
  printf '%-18s %s\n' "$(basename $a)" "$(grep -c SKAdNetworkIdentifier "$a/ios/Runner/Info.plist")"
done
```

足りないアプリがあれば、揃っているアプリの `SKAdNetworkItems` ブロックをそのまま移せばよい。

## 8. 配布用の署名（証明書がキーチェーンから消えたとき）

2026-09-26 に「No signing certificate "iOS Distribution" found」でアーカイブの書き出しが止まった。
Xcode にアカウントがサインインしておらず、配布証明書の秘密鍵も手元に無い状態だった。
Xcode にサインインし直す代わりに、以下の手順で秘密鍵ごと作り直した（パスワード入力が要らない）。

```sh
# 1. 秘密鍵と CSR を作る
mkdir -p ~/.secrets/apple-signing && cd ~/.secrets/apple-signing
openssl req -new -newkey rsa:2048 -nodes -keyout dist.key -out dist.csr \
  -subj "/emailAddress=<メール>/CN=RYOHEI ICHINOMIYA/C=JP"

# 2. developer.apple.com > Certificates > + > Apple Distribution に dist.csr を上げる
#    ブラウザのダウンロードが動かないときは ASC API から取れる:
#    GET /v1/certificates の certificateContent を base64 デコードして dist.cer

# 3. 証明書と秘密鍵を1つにまとめる（-legacy がないと security import が MAC 検証で落ちる）
openssl x509 -inform DER -in dist.cer -out dist.pem
openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12 -passout pass:"$PW"

# 4. 専用キーチェーンに入れる。login キーチェーンだと codesign が GUI の許可待ちで
#    無言のまま固まる（49分待っても進まなかった）。専用キーチェーンなら自分で
#    パスワードを決められるので set-key-partition-list が通る。
security create-keychain -p "$KP" takken.keychain
security set-keychain-settings -lut 21600 takken.keychain
security unlock-keychain -p "$KP" takken.keychain
security import dist.p12 -k takken.keychain -P "$PW" -T /usr/bin/codesign -T /usr/bin/security -A
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KP" takken.keychain
security list-keychains -d user -s takken.keychain ~/Library/Keychains/login.keychain-db

# 5. プロビジョニングプロファイルは ASC API で作れる（POST /v1/profiles, IOS_APP_STORE）。
#    profileContent を base64 デコードして ~/Library/MobileDevice/Provisioning Profiles/<uuid>.mobileprovision へ。

# 6. ExportOptions.plist は signingStyle=manual にして、証明書名とプロファイル名を明記する。
#    アーカイブは API キーで通る:
#    xcodebuild ... archive -allowProvisioningUpdates \
#      -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_3URMU94JK9.p8 \
#      -authenticationKeyID 3URMU94JK9 -authenticationKeyIssuerID <issuer>
#    ただし書き出し(-exportArchive)のクラウド署名は App Manager 権限のキーでは通らない
#    （"Cloud signing permission error"）。だから手動署名にしている。
```

秘密鍵・p12・各パスワードは `~/.secrets/apple-signing/` に置いてある（リポジトリには入れない）。
