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
