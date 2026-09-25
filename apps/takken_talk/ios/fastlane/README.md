# スクリーンショットの提出

1. `../tool/screenshots.sh "iPhone 16 Pro Max" build/shots` と
   `../tool/screenshots.sh "iPad Pro 13-inch (M4)" build/shots_ipad` で素材を撮る。
   **本番APIに向けて撮ること**（`API_BASE=https://<worker> ./tool/screenshots.sh ...`）。
   モックのままだと会話の中身が定型文になって掲載に使えない。
2. `./tool/stage_screenshots.sh` で `ios/fastlane/screenshots/ja/` に並べる。
   iPad のファイル名には `_ipad` を付けること（frameit と deliver がこれでサイズを判別する）。
3. `cd ios && bundle exec fastlane compose_screenshots` で枠と見出しを合成。
4. `cd ios && bundle exec fastlane upload_screenshots` で App Store Connect へ。

App Store Connect のメタデータ（名前・説明・キーワード）は `scripts/asc/` の
スクリプトで入れる。deliver からは触らない（`skip_metadata: true`）。
